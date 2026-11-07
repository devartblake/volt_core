-- Inventory, phase B: the parts catalog, one warehouse, and the stock ledger.
-- See docs/materials_and_inventory_design.md.
--
--   parts_catalog        what a part IS (part number, name, manufacturer)
--   inventory_locations  where stock is kept (one "Main warehouse" per company
--                        for now; the id is the tenant id)
--   inventory_movements  append-only ledger: every receive / adjust / count is a
--                        row, and stock is the sum of a part's rows, so every
--                        number can be traced
--   inventory_stock      view: on hand, reserved and available per part
--
-- Reservations, issue and return (job movements) arrive in phase C; their
-- reasons are allowed here so that migration is not needed again.

begin;

-- ---------------------------------------------------------------------------
-- 1. Parts catalog
-- ---------------------------------------------------------------------------
create table if not exists public.parts_catalog (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  part_number text not null,
  name text not null default '',
  manufacturer text not null default '',
  -- Which material slot it fits (air_filter, oil_filter...); null when general.
  slot_type text,
  unit text not null default 'each',
  min_stock integer not null default 0,
  -- Other part numbers that can be used instead.
  alt_part_numbers text[] not null default '{}',
  notes text not null default '',
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint parts_catalog_part_number_not_blank
    check (length(trim(part_number)) > 0),
  constraint parts_catalog_min_stock_not_negative check (min_stock >= 0),
  constraint parts_catalog_slot_valid check (slot_type is null or slot_type in (
    'air_filter', 'fuel_filter', 'oil_filter', 'lube_filter',
    'fuel_water_separator', 'coolant_filter', 'battery', 'block_heater',
    'racor_filter', 'additional_parts'
  ))
);

-- One catalog entry per part number per company, ignoring case, spaces and
-- punctuation ("AF-123" and "af 123" are the same part).
create unique index if not exists idx_parts_catalog_part_number
  on public.parts_catalog (
    tenant_id,
    upper(regexp_replace(part_number, '[^A-Za-z0-9]', '', 'g'))
  );

drop trigger if exists trg_parts_catalog_updated_at on public.parts_catalog;
create trigger trg_parts_catalog_updated_at
  before update on public.parts_catalog
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Locations
-- ---------------------------------------------------------------------------
create table if not exists public.inventory_locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  kind text not null default 'warehouse',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint inventory_locations_kind_valid
    check (kind in ('warehouse', 'truck', 'other'))
);

drop trigger if exists trg_inventory_locations_updated_at
  on public.inventory_locations;
create trigger trg_inventory_locations_updated_at
  before update on public.inventory_locations
  for each row execute function public.set_updated_at();

-- A "Main warehouse" for every existing company; its id is the tenant id, which
-- is also what the app uses, so no lookup is needed.
insert into public.inventory_locations (id, tenant_id, name, kind)
select t.id, t.id, 'Main warehouse', 'warehouse' from public.tenants t
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Movements (append-only)
-- ---------------------------------------------------------------------------
create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  part_id uuid not null references public.parts_catalog(id) on delete restrict,
  location_id uuid not null references public.inventory_locations(id)
    on delete restrict,

  -- Signed. receive +, adjust +/-, count +/- (the difference found),
  -- issue -, return +, reserve + (reserved goes up), release + (reserved down).
  qty_delta integer not null,
  reason text not null,
  note text not null default '',
  -- inspection:<id>, maintenance:<id> or work_order:<id> once phase C links a
  -- movement to a job.
  job_ref text,

  user_id uuid references auth.users(id) on delete set null,
  at timestamptz not null default now(),

  constraint inventory_movements_reason_valid check (reason in (
    'receive', 'adjust', 'count', 'reserve', 'release', 'issue', 'return'
  )),
  constraint inventory_movements_delta_not_zero check (qty_delta <> 0)
);

create index if not exists idx_inventory_movements_part
  on public.inventory_movements (tenant_id, part_id, at desc);

-- ---------------------------------------------------------------------------
-- 4. Stock view
-- ---------------------------------------------------------------------------
create or replace view public.inventory_stock
with (security_invoker = true) as
select
  p.tenant_id,
  p.id as part_id,
  m.location_id,
  coalesce(sum(m.qty_delta) filter (
    where m.reason in ('receive', 'adjust', 'count', 'issue', 'return')
  ), 0)::integer as on_hand,
  coalesce(sum(m.qty_delta) filter (where m.reason = 'reserve'), 0)::integer
    - coalesce(sum(m.qty_delta) filter (where m.reason = 'release'), 0)::integer
    as reserved
from public.parts_catalog p
join public.inventory_movements m on m.part_id = p.id
group by p.tenant_id, p.id, m.location_id;

-- ---------------------------------------------------------------------------
-- 5. Row-level security
-- ---------------------------------------------------------------------------
alter table public.parts_catalog enable row level security;
alter table public.inventory_locations enable row level security;
alter table public.inventory_movements enable row level security;

revoke all on public.parts_catalog from anon;
revoke all on public.inventory_locations from anon;
revoke all on public.inventory_movements from anon;
revoke all on public.inventory_stock from anon;

-- Everyone in the company can see the catalog, locations and stock, so a
-- technician can check what is available before a job.
drop policy if exists parts_catalog_read on public.parts_catalog;
create policy parts_catalog_read on public.parts_catalog
  for select to authenticated using (public.is_tenant_member(tenant_id));

drop policy if exists inventory_locations_read on public.inventory_locations;
create policy inventory_locations_read on public.inventory_locations
  for select to authenticated using (public.is_tenant_member(tenant_id));

drop policy if exists inventory_movements_read on public.inventory_movements;
create policy inventory_movements_read on public.inventory_movements
  for select to authenticated using (public.is_tenant_member(tenant_id));

-- Only admins manage the catalog and locations.
drop policy if exists parts_catalog_insert on public.parts_catalog;
create policy parts_catalog_insert on public.parts_catalog
  for insert to authenticated
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists parts_catalog_update on public.parts_catalog;
create policy parts_catalog_update on public.parts_catalog
  for update to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists inventory_locations_write on public.inventory_locations;
create policy inventory_locations_write on public.inventory_locations
  for all to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

-- Movements: only admins receive, adjust and count (phase C opens the job
-- reasons to supervisors, dispatchers and technicians). There is no update or
-- delete policy: a wrong entry is corrected with an offsetting adjustment.
drop policy if exists inventory_movements_insert on public.inventory_movements;
create policy inventory_movements_insert on public.inventory_movements
  for insert to authenticated
  with check (
    public.has_tenant_role(tenant_id, array['admin']::public.app_role[])
  );

commit;
