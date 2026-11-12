-- =====================================================================
-- VoltCore: fleet tables + function lockdown, as ONE script.
--
-- Paste the whole file into  Supabase dashboard -> SQL Editor -> New query
-- (project uwivfcxywrzcnyouuydj) and press Run.
--
-- It is the five migration files below, in the order they must run. Every
-- statement is safe to run again ("if not exists" / "drop ... if exists" /
-- "create or replace"), so if something fails you can fix it and re-run the
-- whole script. Generated from supabase/migrations/.
-- =====================================================================

-- ---------------------------------------------------------------------
-- PART 1 of 5: tenant member admin management (safe to run again; already live)
-- source: supabase/migrations/20260825120000_tenant_member_admin_management.sql
-- ---------------------------------------------------------------------

-- Let a tenant admin manage who belongs to the tenant and at what role.
--
-- The app has shipped a "Team & Roles" screen (/admin/technicians) since the
-- RBAC work, but it cannot actually write anything:
--
--   * tenant_members has RLS enabled and only a `members_read` SELECT policy.
--     With no INSERT/UPDATE policy every write is denied, so the role dropdown
--     fails with 42501 no matter who is signed in.
--   * user_profiles is readable only by its owner (`user_profiles_self`), so
--     an admin listing the team sees their own name and a column of
--     "Tenant member" placeholders with no email for everyone else.
--   * There is no way at all to grant a role to somebody who signed up but was
--     never added to the tenant — the screen can only edit rows that already
--     exist.
--
-- This migration closes all three. It changes no existing policy; everything
-- here is additive, and `user_profiles_self` keeps working exactly as before.

begin;

-- ---------------------------------------------------------------------------
-- 1. Admins may write tenant_members
-- ---------------------------------------------------------------------------
-- Bootstrapping note: these policies deliberately require an *existing* active
-- admin, so the first membership of a brand new tenant still cannot be created
-- from the client. That row is seeded out-of-band by
-- supabase/manual/tenant_bootstrap.sql, which runs with elevated rights.

grant select, insert, update, delete on public.tenant_members to authenticated;

drop policy if exists members_admin_insert on public.tenant_members;
create policy members_admin_insert
  on public.tenant_members
  for insert to authenticated
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

drop policy if exists members_admin_update on public.tenant_members;
create policy members_admin_update
  on public.tenant_members
  for update to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  )
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

drop policy if exists members_admin_delete on public.tenant_members;
create policy members_admin_delete
  on public.tenant_members
  for delete to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

-- ---------------------------------------------------------------------------
-- 2. Admins may read the profiles of their own tenant's members
-- ---------------------------------------------------------------------------
-- Scoped to people who are already members of a tenant the caller administers.
-- It is not a directory of every user in the project: discovering somebody who
-- is *not* yet a member goes through the lookup function below instead.

drop policy if exists user_profiles_tenant_admin_read on public.user_profiles;
create policy user_profiles_tenant_admin_read
  on public.user_profiles
  for select to authenticated
  using (
    exists (
      select 1
      from public.tenant_members tm
      where tm.user_id = user_profiles.user_id
        and (
          select public.has_tenant_role(
            tm.tenant_id, array['admin'::public.app_role]
          )
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Look up a not-yet-member by email
-- ---------------------------------------------------------------------------
-- Adding somebody to a tenant needs their user_id, and by definition no RLS
-- policy on user_profiles can expose them: they are not a member of anything
-- the admin can see. Hence a definer function.
--
-- It matches on the **whole** email and returns at most one row, so it answers
-- "is this specific person registered?" and cannot be used to enumerate or
-- prefix-search the user base. `is_member` lets the caller tell "not
-- registered" apart from "already on the team", which are different problems
-- with different fixes.

create or replace function public.admin_lookup_user_by_email(
  p_tenant_id uuid,
  p_email text
)
returns table (
  user_id uuid,
  display_name text,
  email text,
  phone text,
  is_active boolean,
  member_role public.app_role,
  is_member boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- Raise rather than return empty: an admin whose tenant context is
  -- misconfigured would otherwise be told the user does not exist, which sends
  -- them looking in entirely the wrong place.
  if not public.has_tenant_role(
    p_tenant_id, array['admin'::public.app_role]
  ) then
    raise exception using
      errcode = 'insufficient_privilege',
      message = 'Only an active admin of this tenant can look up users.';
  end if;

  return query
  select
    up.user_id,
    up.display_name,
    up.email,
    up.phone,
    up.is_active,
    tm.role,
    (tm.user_id is not null)
  from public.user_profiles up
  left join public.tenant_members tm
    on tm.user_id = up.user_id
   and tm.tenant_id = p_tenant_id
  where lower(btrim(up.email)) = lower(btrim(p_email))
  limit 1;
end
$$;

revoke all on function public.admin_lookup_user_by_email(uuid, text)
  from public, anon;
grant execute on function public.admin_lookup_user_by_email(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. A tenant must keep one active admin
-- ---------------------------------------------------------------------------
-- The controller already refuses to demote the last admin, but that check runs
-- on one device against a list it fetched earlier. Two admins demoting each
-- other at once both pass it. Enforce it where the race actually resolves.

create or replace function public.enforce_last_tenant_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := coalesce(new.tenant_id, old.tenant_id);
  v_active_admins integer;
begin
  -- Deleting a tenant cascades to its memberships. There is no last admin to
  -- protect when the tenant itself is being removed.
  if not exists (select 1 from public.tenants where id = v_tenant_id) then
    return coalesce(new, old);
  end if;

  select count(*) into v_active_admins
  from public.tenant_members
  where tenant_id = v_tenant_id
    and is_active
    and role = 'admin'::public.app_role;

  if v_active_admins = 0 then
    raise exception using
      errcode = 'check_violation',
      message = 'A tenant must keep at least one active admin.';
  end if;

  return coalesce(new, old);
end
$$;

revoke all on function public.enforce_last_tenant_admin()
  from public, anon, authenticated;

drop trigger if exists trg_tenant_members_last_admin on public.tenant_members;
create trigger trg_tenant_members_last_admin
  after update or delete on public.tenant_members
  for each row execute function public.enforce_last_tenant_admin();

commit;

-- ---------------------------------------------------------------------
-- PART 2 of 5: fleet vehicles
-- source: supabase/migrations/20260825140000_fleet_vehicles.sql
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- PART 3 of 5: vehicle maintenance checks (needs part 2)
-- source: supabase/migrations/20260825160000_vehicle_maintenance_checks.sql
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- PART 4 of 5: vehicle assets (needs part 2)
-- source: supabase/migrations/20260825180000_vehicle_assets.sql
-- ---------------------------------------------------------------------

-- Fleet, phase 3: the tools carried in a vehicle.
--
-- Two tables, deliberately:
--
--   vehicle_asset_catalog  what a tool *is*  — "IDEAL ½ EMT BENDER", 74-031
--   vehicle_assets         which van has it  — this specific bender, in Van B
--
-- Separating them is what stops "IDEAL ½ EMT BENDER" being typed five slightly
-- different ways across five vans, which makes "where are all our benders?"
-- unanswerable.
--
-- These are NOT public.equipment. That table is the field-service assets we
-- inspect — generators, transfer switches. See
-- docs/fleet_and_vehicle_assets_plan.md §0 for why sharing the word would make
-- every later conversation ambiguous.

begin;

-- ---------------------------------------------------------------------------
-- 1. Catalog — the master list of tool types
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_asset_catalog (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  name text not null,
  part_number text,
  category text not null default '',
  notes text not null default '',
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint vehicle_asset_catalog_name_not_blank
    check (length(trim(name)) > 0)
);

-- One "IDEAL ½ EMT BENDER" per tenant. Case- and space-insensitive, because
-- the whole point of a catalog is that the same tool is one entry.
create unique index if not exists idx_vehicle_asset_catalog_name
  on public.vehicle_asset_catalog (tenant_id, lower(trim(name)));

-- Part numbers identify a tool type just as well as the name, so a duplicate
-- is a duplicate. Partial: plenty of items have none (push cart, extension
-- cord), and '' would collide all of them with each other.
create unique index if not exists idx_vehicle_asset_catalog_part_number
  on public.vehicle_asset_catalog (tenant_id, upper(trim(part_number)))
  where part_number is not null and length(trim(part_number)) > 0;

drop trigger if exists trg_vehicle_asset_catalog_updated_at
  on public.vehicle_asset_catalog;
create trigger trg_vehicle_asset_catalog_updated_at
  before update on public.vehicle_asset_catalog
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Assets — a specific tool, in a specific vehicle
-- ---------------------------------------------------------------------------
-- ONE ROW PER PHYSICAL ITEM. There is no quantity column, on purpose: the
-- paper form lists the two Werner 8ft ladders as two separate lines, and on
-- the sample one is missing and the other is not. A single row carrying
-- `quantity: 2` cannot express that, which is the whole reason the receipt
-- exists.
create table if not exists public.vehicle_assets (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  catalog_id uuid not null
    references public.vehicle_asset_catalog(id) on delete restrict,

  serial_number text,

  -- fmc | nmc — Fully / Non Mission Capable, the terms already printed on the
  -- form. Keep the crew's vocabulary rather than inventing "ok/broken"; phase
  -- 4's receipt lines record the same two values.
  readiness text not null default 'fmc',

  -- Standing state, updated by the most recent receipt. Distinct from
  -- retired_at: a missing ladder is expected back, a retired one is not.
  is_missing boolean not null default false,

  notes text not null default '',

  assigned_at timestamptz not null default now(),
  retired_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint vehicle_assets_readiness_valid
    check (readiness in ('fmc', 'nmc'))
);

-- `on delete restrict` above is deliberate: deleting a catalog entry that vans
-- still carry would orphan real tools. Deactivate it instead (is_active).

create index if not exists idx_vehicle_assets_vehicle
  on public.vehicle_assets (tenant_id, vehicle_id)
  where retired_at is null;

create index if not exists idx_vehicle_assets_catalog
  on public.vehicle_assets (tenant_id, catalog_id);

-- Serials are the one identifier that must not repeat across the fleet: the
-- same numbered tool cannot be in two vans.
create unique index if not exists idx_vehicle_assets_serial
  on public.vehicle_assets (tenant_id, upper(trim(serial_number)))
  where serial_number is not null
    and length(trim(serial_number)) > 0
    and retired_at is null;

create index if not exists idx_vehicle_assets_attention
  on public.vehicle_assets (tenant_id, vehicle_id)
  where retired_at is null and (is_missing or readiness <> 'fmc');

drop trigger if exists trg_vehicle_assets_updated_at on public.vehicle_assets;
create trigger trg_vehicle_assets_updated_at
  before update on public.vehicle_assets
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. RLS
-- ---------------------------------------------------------------------------
-- A policy per operation, and the grant. A read-only policy set is silent
-- until the first save — see the note in the fleet_vehicles migration.

alter table public.vehicle_asset_catalog enable row level security;
alter table public.vehicle_assets enable row level security;

grant select, insert, update, delete
  on public.vehicle_asset_catalog to authenticated;
grant select, insert, update, delete on public.vehicle_assets to authenticated;

-- Catalog: any member may read it — a technician needs the tool's name to make
-- sense of their own van's list. Only an admin curates it, because a sloppy
-- catalog is what the split exists to prevent.
drop policy if exists vehicle_asset_catalog_read on public.vehicle_asset_catalog;
create policy vehicle_asset_catalog_read
  on public.vehicle_asset_catalog
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

drop policy if exists vehicle_asset_catalog_write on public.vehicle_asset_catalog;
create policy vehicle_asset_catalog_write
  on public.vehicle_asset_catalog
  for all to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  )
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

-- Assets follow their vehicle: a technician sees what is in the van they are
-- stationed to, which is what they signed for.
drop policy if exists vehicle_assets_read on public.vehicle_assets;
create policy vehicle_assets_read
  on public.vehicle_assets
  for select to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_assets.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- Writing stays with dispatch, matching the vehicle record and the maintenance
-- check. A technician signs for what is in the van; they do not change the
-- manifest.
drop policy if exists vehicle_assets_insert on public.vehicle_assets;
create policy vehicle_assets_insert
  on public.vehicle_assets
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists vehicle_assets_update on public.vehicle_assets;
create policy vehicle_assets_update
  on public.vehicle_assets
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

drop policy if exists vehicle_assets_delete on public.vehicle_assets;
create policy vehicle_assets_delete
  on public.vehicle_assets
  for delete to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)));

commit;

-- ---------------------------------------------------------------------
-- PART 5 of 5: lock down anonymous-callable functions
-- source: supabase/migrations/20261103120000_lock_down_anon_functions.sql
-- ---------------------------------------------------------------------

-- Lock down functions that anonymous callers could reach through the Data API.
--
-- Postgres grants EXECUTE on every new function to PUBLIC, so each
-- SECURITY DEFINER helper in the exposed `public` schema was callable at
-- /rest/v1/rpc/<name> by anyone holding the public key, signed in or not.
-- Supabase's security advisor flagged seven of them (lint 0028).
--
-- Every one of these is a helper for row-level-security or storage policies,
-- which only ever run for signed-in users, so anonymous callers have no
-- legitimate use for them:
--
--   can_access_maintenance_asset, can_update_inspection,
--   can_update_maintenance_job, get_active_tenant_id,
--   storage_job_id, storage_tenant_id          -> policy helpers
--   rls_auto_enable                            -> event-trigger function
--
-- Policy helpers keep EXECUTE for `authenticated` (policies are evaluated with
-- the caller's privileges, so they need it) and `service_role` (Edge
-- Functions). `rls_auto_enable` runs from an event trigger and is not meant to
-- be called by anyone through the API, so it loses `authenticated` as well.
--
-- Not changed: the helpers signed-in users legitimately call
-- (has_tenant_role, is_tenant_member, can_manage_tenant_work,
-- is_assigned_technician, admin_lookup_user_by_email, the template RPCs and
-- get_tech_dashboard_stats). Those check the caller's own identity inside.

revoke execute on function public.can_access_maintenance_asset(text)
  from public, anon;
grant execute on function public.can_access_maintenance_asset(text)
  to authenticated, service_role;

revoke execute on function public.can_update_inspection(uuid)
  from public, anon;
grant execute on function public.can_update_inspection(uuid)
  to authenticated, service_role;

revoke execute on function public.can_update_maintenance_job(uuid)
  from public, anon;
grant execute on function public.can_update_maintenance_job(uuid)
  to authenticated, service_role;

revoke execute on function public.get_active_tenant_id()
  from public, anon;
grant execute on function public.get_active_tenant_id()
  to authenticated, service_role;

revoke execute on function public.storage_job_id(text)
  from public, anon;
grant execute on function public.storage_job_id(text)
  to authenticated, service_role;

revoke execute on function public.storage_tenant_id(text)
  from public, anon;
grant execute on function public.storage_tenant_id(text)
  to authenticated, service_role;

revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;

-- =====================================================================
-- OPTIONAL: record these in the migration history, so a later
-- `supabase db push` does not try to apply them a second time.
-- Run it only if the five parts above all succeeded.
-- =====================================================================
-- insert into supabase_migrations.schema_migrations (version, name) values
--   ('20260825120000', 'tenant_member_admin_management'),
--   ('20260825140000', 'fleet_vehicles'),
--   ('20260825160000', 'vehicle_maintenance_checks'),
--   ('20260825180000', 'vehicle_assets'),
--   ('20261103120000', 'lock_down_anon_functions')
-- on conflict (version) do nothing;

-- =====================================================================
-- CHECK: run this afterwards. Expected result: all four tables are
-- non-null, and anon_can_run_* is false for every row.
-- =====================================================================
select
  to_regclass('public.fleet_vehicles')             as fleet_vehicles,
  to_regclass('public.vehicle_maintenance_checks') as vehicle_maintenance_checks,
  to_regclass('public.vehicle_assets')             as vehicle_assets,
  to_regclass('public.vehicle_asset_catalog')      as vehicle_asset_catalog,
  has_function_privilege('anon', 'public.get_active_tenant_id()', 'execute')     as anon_can_run_get_active_tenant_id,
  has_function_privilege('anon', 'public.can_update_inspection(uuid)', 'execute') as anon_can_run_can_update_inspection,
  has_function_privilege('anon', 'public.rls_auto_enable()', 'execute')           as anon_can_run_rls_auto_enable;
