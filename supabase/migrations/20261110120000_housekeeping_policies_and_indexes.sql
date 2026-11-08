-- Housekeeping from the Supabase advisors review (2026-11-10).
--
--   1. vehicle_inspections can be READ only by managers, the inspector, or the
--      vehicle's assigned user (it was open to the whole company). Matches the
--      restriction on vehicle_maintenance_checks.
--   2. Row-level-security policies call auth.uid() as (select auth.uid()) so it
--      is evaluated once per query, not once per row (advisor: auth_rls_initplan).
--   3. inventory_locations: the admin write policy no longer also grants SELECT
--      (advisor: multiple_permissive_policies); everyone in the company still
--      reads through inventory_locations_read.
--   4. Covering indexes for foreign keys on the inventory, vendor, order,
--      approval and vehicle inspection tables (advisor: unindexed_foreign_keys).
--
-- Idempotent. Run once in the Supabase SQL editor.

begin;

-- ---------------------------------------------------------------------------
-- 1. Vehicle inspections: who can read
-- ---------------------------------------------------------------------------
drop policy if exists vehicle_inspections_read on public.vehicle_inspections;
create policy vehicle_inspections_read
  on public.vehicle_inspections
  for select to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or inspector_user_id = (select auth.uid())
    or exists (
      select 1
      from public.fleet_vehicles v
      where v.id = vehicle_inspections.vehicle_id
        and v.tenant_id = vehicle_inspections.tenant_id
        and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------------
-- 2. auth.uid() evaluated once per query
-- ---------------------------------------------------------------------------
drop policy if exists profile_change_requests_read
  on public.profile_change_requests;
create policy profile_change_requests_read on public.profile_change_requests
  for select to authenticated
  using (
    proposed_by = (select auth.uid())
    or public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
  );

drop policy if exists profile_change_requests_insert
  on public.profile_change_requests;
create policy profile_change_requests_insert on public.profile_change_requests
  for insert to authenticated
  with check (
    public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
    or (
      public.is_tenant_member(tenant_id)
      and proposed_by = (select auth.uid())
      and status in ('pending', 'withdrawn')
      and reviewed_by is null
    )
  );

drop policy if exists profile_change_requests_withdraw
  on public.profile_change_requests;
create policy profile_change_requests_withdraw on public.profile_change_requests
  for update to authenticated
  using (
    proposed_by = (select auth.uid())
    and status = 'pending'
    and public.is_tenant_member(tenant_id)
  )
  with check (
    proposed_by = (select auth.uid())
    and status = 'withdrawn'
    and public.is_tenant_member(tenant_id)
  );

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
      public.has_tenant_role(tenant_id, array['technician']::public.app_role[])
      and reason in ('issue', 'return')
      and job_ref is not null
      and (user_id is null or user_id = (select auth.uid()))
    )
  );

-- ---------------------------------------------------------------------------
-- 3. inventory_locations: write policy without the duplicate SELECT
-- ---------------------------------------------------------------------------
drop policy if exists inventory_locations_write on public.inventory_locations;
drop policy if exists inventory_locations_insert on public.inventory_locations;
drop policy if exists inventory_locations_update on public.inventory_locations;
drop policy if exists inventory_locations_delete on public.inventory_locations;

create policy inventory_locations_insert on public.inventory_locations
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

create policy inventory_locations_update on public.inventory_locations
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

create policy inventory_locations_delete on public.inventory_locations
  for delete to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

-- ---------------------------------------------------------------------------
-- 4. Covering indexes for foreign keys
-- ---------------------------------------------------------------------------
create index if not exists idx_asset_parts_updated_by
  on public.asset_parts (updated_by);
create index if not exists idx_job_material_lines_updated_by
  on public.job_material_lines (updated_by);
create index if not exists idx_parts_catalog_updated_by
  on public.parts_catalog (updated_by);

create index if not exists idx_inventory_locations_assigned_user
  on public.inventory_locations (assigned_user_id);
create index if not exists idx_inventory_locations_vehicle
  on public.inventory_locations (vehicle_id);

create index if not exists idx_inventory_movements_location
  on public.inventory_movements (location_id);
create index if not exists idx_inventory_movements_part
  on public.inventory_movements (part_id);
create index if not exists idx_inventory_movements_user
  on public.inventory_movements (user_id);

create index if not exists idx_vendors_updated_by
  on public.vendors (updated_by);
create index if not exists idx_part_prices_part_id
  on public.part_prices (part_id);
create index if not exists idx_part_prices_created_by
  on public.part_prices (created_by);

create index if not exists idx_purchase_orders_updated_by
  on public.purchase_orders (updated_by);
create index if not exists idx_purchase_order_lines_part
  on public.purchase_order_lines (part_id);

create index if not exists idx_profile_change_requests_reviewed_by
  on public.profile_change_requests (reviewed_by);

create index if not exists idx_vehicle_inspections_inspector
  on public.vehicle_inspections (inspector_user_id);
create index if not exists idx_vehicle_inspections_updated_by
  on public.vehicle_inspections (updated_by);
create index if not exists idx_vehicle_inspections_vehicle
  on public.vehicle_inspections (vehicle_id);

commit;
