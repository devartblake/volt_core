-- Voltcore FieldOps Phase 3: versioned, tenant-safe form templates.
--
-- A response stores the exact revision used to collect it. Published revisions
-- are append-only at the application boundary; completed responses are also
-- locked in the database so later template edits cannot rewrite field history.

begin;

create table if not exists public.form_templates (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  slug text not null,
  name text not null,
  description text not null default '',
  asset_type text not null default 'generator',
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_templates_slug_not_blank check (length(trim(slug)) > 0),
  constraint form_templates_name_not_blank check (length(trim(name)) > 0),
  constraint form_templates_tenant_slug_unique unique (tenant_id, slug),
  constraint form_templates_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_revisions (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  template_id uuid not null,
  revision_number integer not null,
  status text not null default 'draft',
  title text not null,
  instructions text not null default '',
  settings jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_template_revisions_number_positive check (revision_number > 0),
  constraint form_template_revisions_status_valid
    check (status in ('draft', 'published', 'archived')),
  constraint form_template_revisions_tenant_template_fk
    foreign key (tenant_id, template_id)
    references public.form_templates (tenant_id, id) on delete restrict,
  constraint form_template_revisions_tenant_number_unique
    unique (tenant_id, template_id, revision_number),
  constraint form_template_revisions_tenant_template_id_unique
    unique (tenant_id, template_id, id),
  constraint form_template_revisions_tenant_id_id_unique unique (tenant_id, id)
);

create unique index if not exists idx_form_template_revisions_one_published
  on public.form_template_revisions (tenant_id, template_id)
  where status = 'published';

create table if not exists public.form_template_sections (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  revision_id uuid not null,
  section_key text not null,
  title text not null,
  description text not null default '',
  position integer not null,
  visibility_rule jsonb not null default '{}'::jsonb,

  constraint form_template_sections_key_not_blank check (length(trim(section_key)) > 0),
  constraint form_template_sections_position_nonnegative check (position >= 0),
  constraint form_template_sections_tenant_revision_fk
    foreign key (tenant_id, revision_id)
    references public.form_template_revisions (tenant_id, id) on delete cascade,
  constraint form_template_sections_tenant_revision_key_unique
    unique (tenant_id, revision_id, section_key),
  constraint form_template_sections_tenant_revision_id_unique
    unique (tenant_id, revision_id, id),
  constraint form_template_sections_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_fields (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  revision_id uuid not null,
  section_id uuid not null,
  field_key text not null,
  label text not null,
  help_text text not null default '',
  field_type text not null,
  position integer not null,
  is_required boolean not null default false,
  validation jsonb not null default '{}'::jsonb,
  visibility_rule jsonb not null default '{}'::jsonb,
  default_value jsonb,

  constraint form_template_fields_key_not_blank check (length(trim(field_key)) > 0),
  constraint form_template_fields_label_not_blank check (length(trim(label)) > 0),
  constraint form_template_fields_type_valid check (
    field_type in (
      'text', 'number', 'date', 'select', 'boolean', 'checklist',
      'reading', 'photo', 'signature'
    )
  ),
  constraint form_template_fields_position_nonnegative check (position >= 0),
  constraint form_template_fields_tenant_revision_fk
    foreign key (tenant_id, revision_id)
    references public.form_template_revisions (tenant_id, id) on delete cascade,
  constraint form_template_fields_tenant_section_fk
    foreign key (tenant_id, revision_id, section_id)
    references public.form_template_sections (tenant_id, revision_id, id)
    on delete cascade,
  constraint form_template_fields_tenant_revision_key_unique
    unique (tenant_id, revision_id, field_key),
  constraint form_template_fields_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_field_options (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  field_id uuid not null,
  option_value text not null,
  label text not null,
  position integer not null,

  constraint form_template_field_options_value_not_blank
    check (length(trim(option_value)) > 0),
  constraint form_template_field_options_label_not_blank
    check (length(trim(label)) > 0),
  constraint form_template_field_options_position_nonnegative check (position >= 0),
  constraint form_template_field_options_tenant_field_fk
    foreign key (tenant_id, field_id)
    references public.form_template_fields (tenant_id, id) on delete cascade,
  constraint form_template_field_options_tenant_field_value_unique
    unique (tenant_id, field_id, option_value)
);

create table if not exists public.form_responses (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  template_id uuid not null,
  template_revision_id uuid not null,
  status text not null default 'draft',
  subject_type text not null default 'asset',
  subject_id uuid,
  customer_id uuid,
  site_id uuid,
  asset_id uuid,
  work_order_id uuid,
  inspection_id uuid,
  maintenance_record_id uuid,
  values jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_responses_status_valid check (status in ('draft', 'completed', 'void')),
  constraint form_responses_subject_type_not_blank check (length(trim(subject_type)) > 0),
  constraint form_responses_tenant_template_fk
    foreign key (tenant_id, template_id)
    references public.form_templates (tenant_id, id) on delete restrict,
  constraint form_responses_tenant_revision_fk
    foreign key (tenant_id, template_revision_id)
    references public.form_template_revisions (tenant_id, id) on delete restrict,
  constraint form_responses_tenant_template_revision_fk
    foreign key (tenant_id, template_id, template_revision_id)
    references public.form_template_revisions (tenant_id, template_id, id)
    on delete restrict
);

create index if not exists idx_form_templates_tenant_asset_active
  on public.form_templates (tenant_id, asset_type, is_archived, name);
create index if not exists idx_form_template_revisions_tenant_template_status
  on public.form_template_revisions (tenant_id, template_id, status, revision_number desc);
create index if not exists idx_form_template_sections_tenant_revision_position
  on public.form_template_sections (tenant_id, revision_id, position);
create index if not exists idx_form_template_fields_tenant_revision_position
  on public.form_template_fields (tenant_id, revision_id, section_id, position);
create index if not exists idx_form_template_field_options_tenant_field_position
  on public.form_template_field_options (tenant_id, field_id, position);
create index if not exists idx_form_responses_tenant_revision_updated
  on public.form_responses (tenant_id, template_revision_id, updated_at desc);
create index if not exists idx_form_responses_tenant_asset_updated
  on public.form_responses (tenant_id, asset_id, updated_at desc)
  where asset_id is not null;

drop trigger if exists trg_form_templates_updated_at on public.form_templates;
create trigger trg_form_templates_updated_at
  before update on public.form_templates
  for each row execute function public.set_updated_at();

drop trigger if exists trg_form_template_revisions_updated_at on public.form_template_revisions;
create trigger trg_form_template_revisions_updated_at
  before update on public.form_template_revisions
  for each row execute function public.set_updated_at();

drop trigger if exists trg_form_responses_updated_at on public.form_responses;
create trigger trg_form_responses_updated_at
  before update on public.form_responses
  for each row execute function public.set_updated_at();

create or replace function public.prevent_completed_form_response_edits()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.status = 'completed' then
    raise exception 'Completed form responses are immutable.';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_completed_form_response_edits()
  from public, anon, authenticated;

drop trigger if exists trg_form_responses_lock_completed on public.form_responses;
create trigger trg_form_responses_lock_completed
  before update on public.form_responses
  for each row execute function public.prevent_completed_form_response_edits();

-- Template definitions are controlled by dispatch/supervisory roles. Active
-- tenant members may read published or draft definitions so offline clients
-- can render the revision selected by a work order. Responses are writable by
-- tenant members, but are never client-deletable.
revoke all on public.form_templates, public.form_template_revisions,
  public.form_template_sections, public.form_template_fields,
  public.form_template_field_options, public.form_responses
  from anon, authenticated;
grant select, insert, update on public.form_templates,
  public.form_template_revisions, public.form_template_sections,
  public.form_template_fields, public.form_template_field_options
  to authenticated;
grant select, insert, update on public.form_responses to authenticated;

alter table public.form_templates enable row level security;
alter table public.form_template_revisions enable row level security;
alter table public.form_template_sections enable row level security;
alter table public.form_template_fields enable row level security;
alter table public.form_template_field_options enable row level security;
alter table public.form_responses enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'form_templates', 'form_template_revisions', 'form_template_sections',
    'form_template_fields', 'form_template_field_options'
  ] loop
    execute format('drop policy if exists %I on public.%I', table_name || '_read', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_manage', table_name);
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select public.is_tenant_member(tenant_id)))',
      table_name || '_read', table_name
    );
    execute format(
      'create policy %I on public.%I for all to authenticated using ((select public.can_manage_tenant_work(tenant_id))) with check ((select public.can_manage_tenant_work(tenant_id)))',
      table_name || '_manage', table_name
    );
  end loop;
end $$;

drop policy if exists form_responses_read on public.form_responses;
drop policy if exists form_responses_insert on public.form_responses;
drop policy if exists form_responses_update on public.form_responses;
create policy form_responses_read on public.form_responses
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));
create policy form_responses_insert on public.form_responses
  for insert to authenticated
  with check ((select public.is_tenant_member(tenant_id)));
create policy form_responses_update on public.form_responses
  for update to authenticated
  using ((select public.is_tenant_member(tenant_id)))
  with check ((select public.is_tenant_member(tenant_id)));

commit;
