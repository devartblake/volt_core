-- Fleet: daily / weekly / monthly vehicle walk-around inspections, synced.
--
-- Until now these lived only on the device (Hive). The app now queues every
-- save/delete through the sync outbox and can pull rows back down, so a second
-- device (dispatcher, another phone) sees the same inspection log.
--
-- `payload` holds the complete inspection as the app stores it (every answer,
-- per-item note, signer names, signature file paths), so no field is lost. The
-- typed columns beside it are for filtering and reporting only.
--
-- Safe to run more than once.

begin;

create table if not exists public.vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,

  -- daily | weekly | monthly
  cadence text not null default 'weekly',
  inspected_at timestamptz not null default now(),
  inspector_user_id uuid references auth.users(id) on delete set null,
  odometer integer not null default 0,

  -- Result summary: items that did not come back OK, and how many outright
  -- failed. Derived by the app from the answers inside `payload`.
  issue_count integer not null default 0,
  fail_count integer not null default 0,
  signed_at timestamptz,

  -- Full entity JSON.
  payload jsonb not null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint vehicle_inspections_cadence_valid
    check (cadence in ('daily', 'weekly', 'monthly')),
  constraint vehicle_inspections_odometer_not_negative
    check (odometer >= 0)
);

create index if not exists idx_vehicle_inspections_vehicle_inspected
  on public.vehicle_inspections (tenant_id, vehicle_id, inspected_at desc);

create index if not exists idx_vehicle_inspections_issues
  on public.vehicle_inspections (tenant_id, inspected_at desc)
  where issue_count > 0;

drop trigger if exists trg_vehicle_inspections_updated_at
  on public.vehicle_inspections;
create trigger trg_vehicle_inspections_updated_at
  before update on public.vehicle_inspections
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.vehicle_inspections enable row level security;

revoke all on public.vehicle_inspections from anon;
grant select, insert, update, delete
  on public.vehicle_inspections to authenticated;

-- Everyone in the tenant can read the log.
drop policy if exists vehicle_inspections_read on public.vehicle_inspections;
create policy vehicle_inspections_read
  on public.vehicle_inspections
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

-- Write: admin / supervisor / dispatcher (can_manage_tenant_work), or the
-- inspector themself (any tenant member recording their own walk-around, e.g.
-- a technician).
drop policy if exists vehicle_inspections_insert on public.vehicle_inspections;
create policy vehicle_inspections_insert
  on public.vehicle_inspections
  for insert to authenticated
  with check (
    (select public.can_manage_tenant_work(tenant_id))
    or (
      inspector_user_id = (select auth.uid())
      and (select public.is_tenant_member(tenant_id))
    )
  );

drop policy if exists vehicle_inspections_update on public.vehicle_inspections;
create policy vehicle_inspections_update
  on public.vehicle_inspections
  for update to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or (
      inspector_user_id = (select auth.uid())
      and (select public.is_tenant_member(tenant_id))
    )
  )
  with check (
    (select public.can_manage_tenant_work(tenant_id))
    or (
      inspector_user_id = (select auth.uid())
      and (select public.is_tenant_member(tenant_id))
    )
  );

drop policy if exists vehicle_inspections_delete on public.vehicle_inspections;
create policy vehicle_inspections_delete
  on public.vehicle_inspections
  for delete to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or (
      inspector_user_id = (select auth.uid())
      and (select public.is_tenant_member(tenant_id))
    )
  );

commit;
