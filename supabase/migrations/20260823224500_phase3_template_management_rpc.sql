-- Phase 3 template management write boundary.
-- Draft definition replacement and publication are transaction-scoped RPCs so
-- a client disconnect cannot leave a partial revision graph behind.

begin;

create or replace function public.save_form_template_draft(p_definition jsonb)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_template jsonb := p_definition -> 'template';
  v_revision jsonb := p_definition -> 'revision';
  v_tenant_id uuid := (p_definition -> 'template' ->> 'tenant_id')::uuid;
  v_template_id uuid := (p_definition -> 'template' ->> 'id')::uuid;
  v_revision_id uuid := (p_definition -> 'revision' ->> 'id')::uuid;
  v_existing_status text;
  item jsonb;
begin
  if auth.uid() is null or not public.can_manage_tenant_work(v_tenant_id) then
    raise exception 'Template management is not permitted for this tenant.';
  end if;

  if (v_revision ->> 'tenant_id')::uuid <> v_tenant_id
     or (v_revision ->> 'template_id')::uuid <> v_template_id then
    raise exception 'Template and revision tenant/template IDs must match.';
  end if;

  if coalesce(v_revision ->> 'status', '') <> 'draft' then
    raise exception 'Only draft revisions can be saved.';
  end if;

  select status into v_existing_status
  from public.form_template_revisions
  where id = v_revision_id
  for update;

  if v_existing_status is not null and v_existing_status <> 'draft' then
    raise exception 'Published or archived revisions are immutable.';
  end if;

  insert into public.form_templates (
    id, tenant_id, slug, name, description, asset_type, is_archived,
    created_at, updated_at
  ) values (
    v_template_id,
    v_tenant_id,
    v_template ->> 'slug',
    v_template ->> 'name',
    coalesce(v_template ->> 'description', ''),
    coalesce(v_template ->> 'asset_type', 'generator'),
    coalesce((v_template ->> 'is_archived')::boolean, false),
    coalesce((v_template ->> 'created_at')::timestamptz, now()),
    now()
  )
  on conflict (id) do update set
    slug = excluded.slug,
    name = excluded.name,
    description = excluded.description,
    asset_type = excluded.asset_type,
    is_archived = excluded.is_archived,
    updated_at = now()
  where public.form_templates.tenant_id = v_tenant_id;

  insert into public.form_template_revisions (
    id, tenant_id, template_id, revision_number, status, title, instructions,
    settings, published_at, created_at, updated_at
  ) values (
    v_revision_id,
    v_tenant_id,
    v_template_id,
    (v_revision ->> 'revision_number')::integer,
    'draft',
    v_revision ->> 'title',
    coalesce(v_revision ->> 'instructions', ''),
    coalesce(v_revision -> 'settings', '{}'::jsonb),
    null,
    coalesce((v_revision ->> 'created_at')::timestamptz, now()),
    now()
  )
  on conflict (id) do update set
    title = excluded.title,
    instructions = excluded.instructions,
    settings = excluded.settings,
    updated_at = now()
  where public.form_template_revisions.tenant_id = v_tenant_id
    and public.form_template_revisions.status = 'draft';

  delete from public.form_template_field_options
  where tenant_id = v_tenant_id
    and field_id in (
      select id from public.form_template_fields
      where tenant_id = v_tenant_id and revision_id = v_revision_id
    );
  delete from public.form_template_fields
  where tenant_id = v_tenant_id and revision_id = v_revision_id;
  delete from public.form_template_sections
  where tenant_id = v_tenant_id and revision_id = v_revision_id;

  for item in select value from jsonb_array_elements(coalesce(p_definition -> 'sections', '[]'::jsonb)) loop
    if (item ->> 'tenant_id')::uuid <> v_tenant_id
       or (item ->> 'revision_id')::uuid <> v_revision_id then
      raise exception 'Section ownership does not match the draft revision.';
    end if;
    insert into public.form_template_sections (
      id, tenant_id, revision_id, section_key, title, description, position,
      visibility_rule
    ) values (
      (item ->> 'id')::uuid, v_tenant_id, v_revision_id,
      item ->> 'section_key', item ->> 'title',
      coalesce(item ->> 'description', ''), (item ->> 'position')::integer,
      coalesce(item -> 'visibility_rule', '{}'::jsonb)
    );
  end loop;

  for item in select value from jsonb_array_elements(coalesce(p_definition -> 'fields', '[]'::jsonb)) loop
    if (item ->> 'tenant_id')::uuid <> v_tenant_id
       or (item ->> 'revision_id')::uuid <> v_revision_id then
      raise exception 'Field ownership does not match the draft revision.';
    end if;
    insert into public.form_template_fields (
      id, tenant_id, revision_id, section_id, field_key, label, help_text,
      field_type, position, is_required, validation, visibility_rule,
      default_value
    ) values (
      (item ->> 'id')::uuid, v_tenant_id, v_revision_id,
      (item ->> 'section_id')::uuid, item ->> 'field_key', item ->> 'label',
      coalesce(item ->> 'help_text', ''), item ->> 'field_type',
      (item ->> 'position')::integer,
      coalesce((item ->> 'is_required')::boolean, false),
      coalesce(item -> 'validation', '{}'::jsonb),
      coalesce(item -> 'visibility_rule', '{}'::jsonb), item -> 'default_value'
    );
  end loop;

  for item in select value from jsonb_array_elements(coalesce(p_definition -> 'options', '[]'::jsonb)) loop
    if (item ->> 'tenant_id')::uuid <> v_tenant_id then
      raise exception 'Option ownership does not match the draft revision.';
    end if;
    insert into public.form_template_field_options (
      id, tenant_id, field_id, option_value, label, position
    ) values (
      (item ->> 'id')::uuid, v_tenant_id, (item ->> 'field_id')::uuid,
      item ->> 'option_value', item ->> 'label', (item ->> 'position')::integer
    );
  end loop;

  return v_revision_id;
end;
$$;

create or replace function public.publish_form_template_revision(p_revision_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_tenant_id uuid;
  v_template_id uuid;
  v_status text;
begin
  select tenant_id, template_id, status
    into v_tenant_id, v_template_id, v_status
  from public.form_template_revisions
  where id = p_revision_id
  for update;

  if v_tenant_id is null then
    raise exception 'Template revision not found.';
  end if;
  if auth.uid() is null or not public.can_manage_tenant_work(v_tenant_id) then
    raise exception 'Template management is not permitted for this tenant.';
  end if;
  if v_status <> 'draft' then
    raise exception 'Only a draft template revision can be published.';
  end if;

  update public.form_template_revisions
  set status = 'archived', updated_at = now()
  where tenant_id = v_tenant_id
    and template_id = v_template_id
    and status = 'published'
    and id <> p_revision_id;

  update public.form_template_revisions
  set status = 'published', published_at = now(), updated_at = now()
  where id = p_revision_id and tenant_id = v_tenant_id and status = 'draft';

  return p_revision_id;
end;
$$;

revoke all on function public.save_form_template_draft(jsonb)
  from public, anon;
revoke all on function public.publish_form_template_revision(uuid)
  from public, anon;
grant execute on function public.save_form_template_draft(jsonb)
  to authenticated;
grant execute on function public.publish_form_template_revision(uuid)
  to authenticated;

commit;
