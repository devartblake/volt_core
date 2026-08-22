-- Voltcore FieldOps Phase 2 follow-up: correct inherited broad grants on the
-- deployed customer/site tables. Migration 0007 now includes these commands
-- for fresh environments; this file brings the already-applied environment to
-- the same least-privilege state.

begin;

revoke all on public.customers from anon, authenticated;
grant select, insert, update on public.customers to authenticated;

revoke all on public.sites from anon, authenticated;
grant select, insert, update on public.sites to authenticated;

drop policy if exists customers_manage on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
create policy customers_insert on public.customers
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));
create policy customers_update on public.customers
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists sites_manage on public.sites;
drop policy if exists sites_write on public.sites;
drop policy if exists sites_insert on public.sites;
drop policy if exists sites_update on public.sites;
create policy sites_insert on public.sites
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));
create policy sites_update on public.sites
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

commit;
