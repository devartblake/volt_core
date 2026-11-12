-- A person can belong to more than one division.
--
-- Run AFTER 20261113110000_divisions.sql.
--
--   * public.member_divisions: one row per (person, division). Every member of
--     the company can read it; only admins write. A trigger refuses a division
--     from another company.
--   * Existing tenant_members.division_id values are copied across.
--   * tenant_members.division_id is DEPRECATED but left in place so older app
--     builds keep working. New builds read member_divisions and use the old
--     column only as a fallback for people with no member_divisions rows, and
--     keep it equal to the first chosen division.
--   * Audit: insert and delete are logged by a small dedicated trigger
--     (audit_log.table_name has no CHECK, so no ALTER of audit_log is needed).
--
-- Idempotent: safe to run more than once.

begin;

create table if not exists public.member_divisions (
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null,
  division_id uuid not null references public.divisions(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, division_id)
);

create index if not exists idx_member_divisions_tenant
  on public.member_divisions (tenant_id, division_id);

-- A member can only be placed in a division of their own company.
create or replace function public.check_member_divisions_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.divisions d
     where d.id = new.division_id and d.tenant_id = new.tenant_id
  ) then
    raise exception 'That division belongs to another company.'
      using errcode = 'foreign_key_violation';
  end if;
  return new;
end;
$$;

revoke all on function public.check_member_divisions_tenant()
  from public, anon, authenticated;

drop trigger if exists trg_member_divisions_check on public.member_divisions;
create trigger trg_member_divisions_check
  before insert or update on public.member_divisions
  for each row execute function public.check_member_divisions_tenant();

alter table public.member_divisions enable row level security;
revoke all on public.member_divisions from public;
revoke all on public.member_divisions from anon;
grant select, insert, delete on public.member_divisions to authenticated;

drop policy if exists member_divisions_read on public.member_divisions;
create policy member_divisions_read on public.member_divisions
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists member_divisions_insert on public.member_divisions;
create policy member_divisions_insert on public.member_divisions
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists member_divisions_delete on public.member_divisions;
create policy member_divisions_delete on public.member_divisions
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

comment on column public.tenant_members.division_id is
  'DEPRECATED: use public.member_divisions. Kept for older app builds; new builds keep it equal to the first chosen division.';

-- Copy the single division each member already has.
insert into public.member_divisions (tenant_id, user_id, division_id)
select tm.tenant_id, tm.user_id, tm.division_id
  from public.tenant_members tm
 where tm.division_id is not null
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Audit
-- ---------------------------------------------------------------------------
create or replace function public.audit_member_division_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_row public.member_divisions;
  v_name text;
  v_division text;
  v_summary text;
begin
  v_row := case when tg_op = 'DELETE' then old else new end;

  v_name := coalesce(
    (select nullif(up.display_name, '')
       from public.user_profiles up
      where up.user_id = v_row.user_id),
    v_row.user_id::text);
  v_division := coalesce(
    (select d.name from public.divisions d where d.id = v_row.division_id),
    'a division');

  v_summary := case tg_op
    when 'INSERT' then 'Added ' || v_name || ' to division ' || v_division
    else 'Removed ' || v_name || ' from division ' || v_division
  end;

  begin
    insert into public.audit_log (
      tenant_id, table_name, record_id, action, actor_user_id,
      old_data, new_data, summary
    ) values (
      v_row.tenant_id,
      'member_divisions',
      v_row.user_id || ':' || v_row.division_id,
      lower(tg_op),
      auth.uid(),
      case when tg_op = 'DELETE'
           then jsonb_build_object('user_id', old.user_id,
                                   'division_id', old.division_id) end,
      case when tg_op = 'INSERT'
           then jsonb_build_object('user_id', new.user_id,
                                   'division_id', new.division_id) end,
      left(v_summary, 500)
    );
  exception when others then
    raise warning 'audit_log write failed for member_divisions: %', sqlerrm;
  end;

  return null;
end;
$$;

revoke all on function public.audit_member_division_change()
  from public, anon, authenticated;

drop trigger if exists trg_audit_member_divisions on public.member_divisions;
create trigger trg_audit_member_divisions
  after insert or delete on public.member_divisions
  for each row execute function public.audit_member_division_change();

commit;
