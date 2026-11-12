-- Divisions and the apprentice role, step 2 of 2.
--
-- Run order: 20261113100000_apprentice_role.sql FIRST (it adds the enum value
-- 'apprentice' and must commit before this file uses it), then this file.
--
-- What this does:
--   1. public.divisions: a company-defined list (for example "Generators",
--      "Fire alarm"). Any member of the company can read it; only admins can
--      add, rename, reorder or deactivate. Names are unique per company,
--      ignoring case.
--   2. tenant_members.division_id: each user may belong to one division
--      (optional, any role). Deleting a division clears it from its members.
--      A trigger refuses a division from another company.
--   3. Lets apprentices do what technicians can do at the database level:
--      is_assigned_technician() and the inventory_movements insert policy
--      (issue / return against a named job, in their own name). Nothing else
--      is loosened.
--
-- The audit log trigger on tenant_members (20261112100000_audit_log.sql) is
-- generic over the row's JSON, so a change to division_id is recorded as a
-- "Changed team member" entry with no change to that trigger.
--
-- Idempotent: safe to run more than once.

begin;

-- ---------------------------------------------------------------------------
-- 1. divisions
-- ---------------------------------------------------------------------------
create table if not exists public.divisions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint divisions_name_not_blank check (length(trim(name)) > 0)
);

create unique index if not exists idx_divisions_tenant_name
  on public.divisions (tenant_id, lower(name));
create index if not exists idx_divisions_tenant_sort
  on public.divisions (tenant_id, sort_order, name);

drop trigger if exists trg_divisions_updated_at on public.divisions;
create trigger trg_divisions_updated_at
  before update on public.divisions
  for each row execute function public.set_updated_at();

alter table public.divisions enable row level security;
revoke all on public.divisions from anon;
grant select, insert, update, delete on public.divisions to authenticated;

drop policy if exists divisions_read on public.divisions;
create policy divisions_read on public.divisions
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists divisions_insert on public.divisions;
create policy divisions_insert on public.divisions
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists divisions_update on public.divisions;
create policy divisions_update on public.divisions
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists divisions_delete on public.divisions;
create policy divisions_delete on public.divisions
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- 2. tenant_members.division_id
-- ---------------------------------------------------------------------------
alter table public.tenant_members
  add column if not exists division_id uuid
  references public.divisions(id) on delete set null;

create index if not exists idx_tenant_members_division
  on public.tenant_members (division_id)
  where division_id is not null;

-- A member can only be placed in a division of their own company.
create or replace function public.check_member_division_tenant()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.division_id is not null
     and not exists (
       select 1 from public.divisions d
        where d.id = new.division_id and d.tenant_id = new.tenant_id
     ) then
    raise exception 'That division belongs to another company.'
      using errcode = 'foreign_key_violation';
  end if;
  return new;
end;
$$;

revoke all on function public.check_member_division_tenant() from public, anon, authenticated;

drop trigger if exists trg_tenant_members_division_check on public.tenant_members;
create trigger trg_tenant_members_division_check
  before insert or update of division_id, tenant_id on public.tenant_members
  for each row execute function public.check_member_division_tenant();

-- ---------------------------------------------------------------------------
-- 3. Apprentices can act as technicians where technicians are allowed
-- ---------------------------------------------------------------------------
create or replace function public.is_assigned_technician(p_tenant_id uuid, p_user_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select p_user_id = (select auth.uid())
     and public.has_tenant_role(
           p_tenant_id,
           array['technician', 'apprentice']::public.app_role[])
$$;

drop policy if exists inventory_movements_insert on public.inventory_movements;
create policy inventory_movements_insert on public.inventory_movements
  for insert to authenticated
  with check (
    public.has_tenant_role(tenant_id, array['admin']::public.app_role[])
    or (
      public.has_tenant_role(
        tenant_id,
        array['supervisor', 'dispatcher']::public.app_role[]
      )
      and (
        (reason in ('reserve', 'release', 'issue', 'return')
          and job_ref is not null)
        or reason = 'transfer'
      )
    )
    or (
      -- Technicians and apprentices: what they used on a job (issue) and what
      -- they put back (return), always against a named job, in their own name.
      public.has_tenant_role(
        tenant_id,
        array['technician', 'apprentice']::public.app_role[]
      )
      and reason in ('issue', 'return')
      and job_ref is not null
      and (user_id is null or user_id = (select auth.uid()))
    )
  );

commit;
