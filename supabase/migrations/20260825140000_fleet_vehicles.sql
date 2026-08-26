-- Fleet, phase 1: the vehicle record.
--
-- Deliberately NOT a row in public.equipment, despite migration 0006 offering
-- that table as "the shared registry for all field-service asset types".
-- Equipment is keyed by an identity_key derived from a serial number or an
-- inspection, and its columns are inspection-shaped (latest_inspection_id,
-- inspection_count, last_inspection_at). A vehicle's identity is its VIN and
-- its lifecycle is odometer-driven, so reusing that table would push plate,
-- odometer and service intervals into metadata jsonb where nothing can
-- constrain or index them. See docs/fleet_and_vehicle_assets_plan.md §1.
--
-- Vehicle assets (the tools carried in a van) and the maintenance checklist
-- arrive in later phases; this migration is only the vehicle itself.

begin;

create table if not exists public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- How the crew refers to it: "Truck A", "Work Van B". This, not the VIN, is
  -- what goes at the top of a paper form, so it is the human key.
  designation text not null,

  -- Nullable on purpose: a vehicle gets added to the system before somebody
  -- walks out to the lot and reads the plate off it.
  vin text,
  license_plate text,
  make text not null default '',
  model text not null default '',
  model_year integer,

  -- van | truck | other
  vehicle_type text not null default 'van',

  -- Current reading. Updated by each maintenance check once phase 2 lands.
  odometer integer not null default 0,

  -- active | maintenance | out_of_service | retired
  --
  -- Spelled 'maintenance' rather than the plan's 'in_service': "in service"
  -- reads as both "in use" and "being serviced", which are opposites here.
  status text not null default 'active',

  -- The technician stationed to this vehicle. They are responsible for it and
  -- for its assets, and they sign for it when it is dispatched — which is why
  -- this column, and not a role check alone, decides what a tech can see.
  assigned_to_user_id uuid references auth.users(id) on delete set null,

  notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint fleet_vehicles_designation_not_blank
    check (length(trim(designation)) > 0),
  constraint fleet_vehicles_type_valid
    check (vehicle_type in ('van', 'truck', 'other')),
  constraint fleet_vehicles_status_valid
    check (status in ('active', 'maintenance', 'out_of_service', 'retired')),
  constraint fleet_vehicles_odometer_not_negative
    check (odometer >= 0),
  -- 17 characters, and never I/O/Q — those are excluded from the VIN alphabet
  -- precisely because they are misread as 1/0/0, which is the failure mode
  -- when someone copies one off a doorframe by hand.
  constraint fleet_vehicles_vin_shape
    check (vin is null or vin ~ '^[A-HJ-NPR-Z0-9]{17}$')
);

-- One "Truck A" per tenant among vehicles still in the fleet. Retired ones are
-- excluded so a designation can be reused when a vehicle is replaced.
create unique index if not exists idx_fleet_vehicles_designation
  on public.fleet_vehicles (tenant_id, lower(trim(designation)))
  where status <> 'retired';

create unique index if not exists idx_fleet_vehicles_vin
  on public.fleet_vehicles (tenant_id, vin)
  where vin is not null;

create index if not exists idx_fleet_vehicles_tenant_status
  on public.fleet_vehicles (tenant_id, status);

create index if not exists idx_fleet_vehicles_assignee
  on public.fleet_vehicles (tenant_id, assigned_to_user_id)
  where assigned_to_user_id is not null;

drop trigger if exists trg_fleet_vehicles_updated_at on public.fleet_vehicles;
create trigger trg_fleet_vehicles_updated_at
  before update on public.fleet_vehicles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
-- A policy per operation, and the grant. tenant_members shipped with RLS on
-- and only a SELECT policy, so every write failed 42501 for everyone including
-- admins and the screen was inert until somebody finally read the log. A
-- read-only policy set is silent until the first save.

alter table public.fleet_vehicles enable row level security;

grant select, insert, update, delete on public.fleet_vehicles to authenticated;

-- Managers see the whole fleet; a technician sees the vehicle they are
-- stationed to and nothing else. can_manage_tenant_work() already resolves to
-- exactly admin/supervisor/dispatcher, so the database and RouteRoles cannot
-- drift apart by open-coding the role list twice.
drop policy if exists fleet_vehicles_read on public.fleet_vehicles;
create policy fleet_vehicles_read
  on public.fleet_vehicles
  for select to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or (
      (select public.is_tenant_member(tenant_id))
      and assigned_to_user_id = (select auth.uid())
    )
  );

-- Writes stay with dispatch. A technician signs for a vehicle; they do not
-- edit the fleet record, and phase 4's signature lands on its own table.
drop policy if exists fleet_vehicles_insert on public.fleet_vehicles;
create policy fleet_vehicles_insert
  on public.fleet_vehicles
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists fleet_vehicles_update on public.fleet_vehicles;
create policy fleet_vehicles_update
  on public.fleet_vehicles
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists fleet_vehicles_delete on public.fleet_vehicles;
create policy fleet_vehicles_delete
  on public.fleet_vehicles
  for delete to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)));

commit;
