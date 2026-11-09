-- Per-user permission overrides.
--
-- The app has a fixed catalogue of named permissions (see
-- lib/modules/permissions/domain/permission.dart). Each role has a default for
-- each one. An admin can give a person an override per permission:
--   'allow'  grant it even though their role does not have it
--   'deny'   take it away even though their role has it
-- No row means "use the role default".
--
-- IMPORTANT: this is enforced in the APP only. Database access (row level
-- security) is still decided by the person's role. An 'allow' on its own does
-- not let the database accept a write the role could not make before.
-- Admin-only functions (users, permissions, audit log, settings) are not in
-- the catalogue and cannot be overridden.
--
-- Access:
--   * admins of the company: select / insert / update / delete every row
--   * a member: select their own rows only (so the app can apply them)
--   * nobody else, and no other writes
--
-- Audited by a small dedicated trigger (the generic log_row_change() has no
-- label for this table). audit_log.table_name has no CHECK constraint, so no
-- ALTER of audit_log is needed.
--
-- Idempotent: safe to run more than once.

begin;

create table if not exists public.member_permission_overrides (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null,
  permission text not null,
  effect text not null,
  updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (tenant_id, user_id, permission),
  constraint member_permission_overrides_effect_valid
    check (effect in ('allow', 'deny')),
  constraint member_permission_overrides_permission_valid
    check (length(permission) between 1 and 64
           and permission ~ '^[a-z][a-z0-9_]*$')
);

create index if not exists idx_member_permission_overrides_user
  on public.member_permission_overrides (user_id);

drop trigger if exists trg_member_permission_overrides_updated_at
  on public.member_permission_overrides;
create trigger trg_member_permission_overrides_updated_at
  before update on public.member_permission_overrides
  for each row execute function public.set_updated_at();

alter table public.member_permission_overrides enable row level security;
revoke all on public.member_permission_overrides from public;
revoke all on public.member_permission_overrides from anon;
grant select, insert, update, delete
  on public.member_permission_overrides to authenticated;

drop policy if exists member_permission_overrides_admin_select
  on public.member_permission_overrides;
create policy member_permission_overrides_admin_select
  on public.member_permission_overrides
  for select to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists member_permission_overrides_self_select
  on public.member_permission_overrides;
create policy member_permission_overrides_self_select
  on public.member_permission_overrides
  for select to authenticated
  using (
    user_id = (select auth.uid())
    and public.is_tenant_member(tenant_id)
  );

drop policy if exists member_permission_overrides_admin_insert
  on public.member_permission_overrides;
create policy member_permission_overrides_admin_insert
  on public.member_permission_overrides
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists member_permission_overrides_admin_update
  on public.member_permission_overrides;
create policy member_permission_overrides_admin_update
  on public.member_permission_overrides
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists member_permission_overrides_admin_delete
  on public.member_permission_overrides;
create policy member_permission_overrides_admin_delete
  on public.member_permission_overrides
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------
create or replace function public.audit_member_permission_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.member_permission_overrides;
  v_name text;
  v_perm text;
  v_summary text;
begin
  v_row := case when tg_op = 'DELETE' then old else new end;

  v_name := coalesce(
    (select nullif(up.display_name, '')
       from public.user_profiles up
      where up.user_id = v_row.user_id),
    v_row.user_id::text);
  v_perm := replace(v_row.permission, '_', ' ');

  v_summary := case tg_op
    when 'INSERT' then
      case v_row.effect when 'allow' then 'Allowed ' else 'Denied ' end
        || v_perm || ' for ' || v_name
    when 'UPDATE' then
      'Changed ' || v_perm || ' for ' || v_name || ' to '
        || case v_row.effect when 'allow' then 'allowed' else 'denied' end
    else
      'Reset ' || v_perm || ' to the role default for ' || v_name
  end;

  begin
    insert into public.audit_log (
      tenant_id, table_name, record_id, action, actor_user_id,
      old_data, new_data, summary
    ) values (
      v_row.tenant_id,
      'member_permission_overrides',
      v_row.tenant_id || ':' || v_row.user_id || ':' || v_row.permission,
      lower(tg_op),
      auth.uid(),
      case when tg_op in ('UPDATE', 'DELETE')
           then jsonb_build_object('permission', old.permission,
                                   'effect', old.effect,
                                   'user_id', old.user_id) end,
      case when tg_op in ('INSERT', 'UPDATE')
           then jsonb_build_object('permission', new.permission,
                                   'effect', new.effect,
                                   'user_id', new.user_id) end,
      left(v_summary, 500)
    );
  exception when others then
    raise warning 'audit_log write failed for member_permission_overrides: %',
      sqlerrm;
  end;

  return null;
end;
$$;

revoke all on function public.audit_member_permission_change()
  from public, anon, authenticated;

drop trigger if exists trg_audit_member_permission_overrides
  on public.member_permission_overrides;
create trigger trg_audit_member_permission_overrides
  after insert or update or delete on public.member_permission_overrides
  for each row execute function public.audit_member_permission_change();

commit;
