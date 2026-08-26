-- Fleet, phase 2: the vehicle maintenance checklist.
--
-- The paper form is filled in repeatedly and the history is the point, so a
-- check is an **event row**, not a set of columns on the vehicle. "When was
-- Truck A last serviced, and by whom?" has to be answerable, and columns that
-- get overwritten cannot answer it.
--
-- The vehicle still carries the *latest* odometer and check date, denormalised
-- below, so the fleet list does not need a correlated subquery per row.

begin;

-- ---------------------------------------------------------------------------
-- 1. Latest-values cache on the vehicle
-- ---------------------------------------------------------------------------
alter table public.fleet_vehicles
  add column if not exists last_check_at timestamptz;

create index if not exists idx_fleet_vehicles_last_check
  on public.fleet_vehicles (tenant_id, last_check_at desc nulls last);

-- ---------------------------------------------------------------------------
-- 2. The checks themselves
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_maintenance_checks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,

  checked_at timestamptz not null default now(),
  checked_by_user_id uuid references auth.users(id) on delete set null,

  -- Reading at the time of the check. This is what advances the vehicle's
  -- odometer.
  odometer integer not null default 0,

  -- From the paper form. Nullable throughout: a walk-around that only reads
  -- the mileage is still a valid record, and forcing a date would get a made
  -- up one.
  last_oil_change_at date,
  last_lubricant_check_at date,
  odometer_at_last_service integer,

  -- ok | attention | fail. Short enums rather than free text, so "which
  -- vehicles have a failing brake check?" is a query and not a grep.
  brake_status text not null default 'ok',
  battery_status text not null default 'ok',

  notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint vehicle_checks_odometer_not_negative
    check (odometer >= 0),
  constraint vehicle_checks_last_service_not_negative
    check (odometer_at_last_service is null or odometer_at_last_service >= 0),
  constraint vehicle_checks_brake_status_valid
    check (brake_status in ('ok', 'attention', 'fail')),
  constraint vehicle_checks_battery_status_valid
    check (battery_status in ('ok', 'attention', 'fail'))
);

create index if not exists idx_vehicle_checks_vehicle_checked
  on public.vehicle_maintenance_checks (tenant_id, vehicle_id, checked_at desc);

create index if not exists idx_vehicle_checks_attention
  on public.vehicle_maintenance_checks (tenant_id, checked_at desc)
  where brake_status <> 'ok' or battery_status <> 'ok';

drop trigger if exists trg_vehicle_checks_updated_at
  on public.vehicle_maintenance_checks;
create trigger trg_vehicle_checks_updated_at
  before update on public.vehicle_maintenance_checks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Keep the vehicle's cached values honest
-- ---------------------------------------------------------------------------
-- The client updates these too, so the fleet list is right immediately after a
-- save while offline. This trigger is what keeps them right when a *second*
-- device syncs a check the first has never seen — without it the cache would
-- reflect whichever device last wrote the vehicle row, not the newest check.
--
-- Only ever moves forward. A backdated check being synced late must not drag
-- the odometer down.
create or replace function public.refresh_vehicle_check_cache()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_vehicle_id uuid := coalesce(new.vehicle_id, old.vehicle_id);
begin
  update public.fleet_vehicles v
     set last_check_at = greatest(
           coalesce(v.last_check_at, latest.checked_at),
           latest.checked_at
         ),
         odometer = greatest(v.odometer, latest.odometer)
    from (
      select checked_at, odometer
        from public.vehicle_maintenance_checks
       where vehicle_id = v_vehicle_id
       order by checked_at desc, created_at desc
       limit 1
    ) as latest
   where v.id = v_vehicle_id;

  return coalesce(new, old);
end
$$;

revoke all on function public.refresh_vehicle_check_cache()
  from public, anon, authenticated;

drop trigger if exists trg_vehicle_checks_refresh_cache
  on public.vehicle_maintenance_checks;
create trigger trg_vehicle_checks_refresh_cache
  after insert or update or delete on public.vehicle_maintenance_checks
  for each row execute function public.refresh_vehicle_check_cache();

-- ---------------------------------------------------------------------------
-- 4. RLS
-- ---------------------------------------------------------------------------
-- A policy per operation, and the grant — see the note in the fleet_vehicles
-- migration for why a read-only policy set is a silent failure.

alter table public.vehicle_maintenance_checks enable row level security;

grant select, insert, update, delete
  on public.vehicle_maintenance_checks to authenticated;

-- Read follows the vehicle: a technician sees the service history of the
-- vehicle they are stationed to, which is the history they are responsible
-- for. Managers see all of it.
drop policy if exists vehicle_checks_read on public.vehicle_maintenance_checks;
create policy vehicle_checks_read
  on public.vehicle_maintenance_checks
  for select to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_maintenance_checks.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- Writing stays with dispatch, matching how the fleet record itself is
-- managed. Widening this to let a technician record their own walk-around is a
-- one-policy change if that turns out to be how the work actually flows.
drop policy if exists vehicle_checks_insert on public.vehicle_maintenance_checks;
create policy vehicle_checks_insert
  on public.vehicle_maintenance_checks
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists vehicle_checks_update on public.vehicle_maintenance_checks;
create policy vehicle_checks_update
  on public.vehicle_maintenance_checks
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists vehicle_checks_delete on public.vehicle_maintenance_checks;
create policy vehicle_checks_delete
  on public.vehicle_maintenance_checks
  for delete to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)));

commit;
