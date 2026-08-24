-- Tenant retention-policy configuration.
--
-- This migration stores policy intent only. It deliberately does not delete
-- compliance evidence. Automated destructive enforcement remains disabled
-- until storage-object cleanup and evidence retention are certified together.

begin;

create table if not exists public.tenant_retention_policies (
  tenant_id uuid primary key references public.tenants(id) on delete cascade,
  archived_maintenance_days integer,
  generated_report_days integer,
  updated_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_retention_archived_maintenance_range check (
    archived_maintenance_days is null
    or archived_maintenance_days between 365 and 3650
  ),
  constraint tenant_retention_generated_report_range check (
    generated_report_days is null
    or generated_report_days between 365 and 3650
  )
);

alter table public.tenant_retention_policies enable row level security;

revoke all on public.tenant_retention_policies from anon, authenticated;
grant select, insert, update on public.tenant_retention_policies to authenticated;

drop policy if exists tenant_retention_policies_read
  on public.tenant_retention_policies;
drop policy if exists tenant_retention_policies_manage
  on public.tenant_retention_policies;

create policy tenant_retention_policies_read
  on public.tenant_retention_policies
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

create policy tenant_retention_policies_manage
  on public.tenant_retention_policies
  for all to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  )
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

commit;
