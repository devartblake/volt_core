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
