-- Tenant-authoritative RBAC audit trail.
--
-- Runtime authorization comes from tenant_members. This table records changes
-- to that authoritative membership role without depending on the legacy
-- technicians table.

begin;

create table if not exists public.tenant_role_assignments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  previous_role public.app_role not null,
  new_role public.app_role not null,
  assigned_by_user_id uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

create index if not exists idx_tenant_role_assignments_tenant_created
  on public.tenant_role_assignments (tenant_id, created_at desc);
create index if not exists idx_tenant_role_assignments_user_created
  on public.tenant_role_assignments (user_id, created_at desc);
create index if not exists idx_tenant_role_assignments_actor
  on public.tenant_role_assignments (assigned_by_user_id)
  where assigned_by_user_id is not null;

alter table public.tenant_role_assignments enable row level security;

revoke all on public.tenant_role_assignments from anon, authenticated;
grant select, insert on public.tenant_role_assignments to authenticated;

drop policy if exists tenant_role_assignments_read
  on public.tenant_role_assignments;
drop policy if exists tenant_role_assignments_insert
  on public.tenant_role_assignments;

create policy tenant_role_assignments_read
  on public.tenant_role_assignments
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

create policy tenant_role_assignments_insert
  on public.tenant_role_assignments
  for insert to authenticated
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

commit;
