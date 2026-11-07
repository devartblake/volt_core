-- Materials, phase A: what a generator takes, and what a job used.
-- See docs/materials_and_inventory_design.md.
--
--   asset_parts          the PARTS PROFILE of one generator (its filters,
--                        battery, heater...), recorded once and reused
--   job_material_lines   what a specific inspection / maintenance / work order
--                        found, needs, or used
--
-- Both carry the same four item fields: part number, quantity, date used
-- (optional) and part name / manufacturer. The parts catalog, stock and
-- reservations come in phases B and C and will reference these by part number.
--
-- `maintenance_parts_used` (empty) is left alone for now; job_material_lines
-- supersedes it and it can be dropped once nothing references it.

begin;

-- ---------------------------------------------------------------------------
-- 1. Generator parts profile
-- ---------------------------------------------------------------------------
create table if not exists public.asset_parts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- Normalised "make|model|serial" of the generator. A text key rather than a
  -- foreign key because inspections create generators before they exist in
  -- public.equipment; equipment_id can be linked later.
  equipment_key text not null,
  make text not null default '',
  model text not null default '',
  serial_number text not null default '',

  slot_type text not null,
  role text not null default 'none',
  sort_order integer not null default 0,

  part_number text not null default '',
  part_name text not null default '',
  manufacturer text not null default '',
  quantity integer not null default 1,
  date_used date,
  notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint asset_parts_slot_valid check (slot_type in (
    'air_filter', 'fuel_filter', 'oil_filter', 'lube_filter',
    'fuel_water_separator', 'coolant_filter', 'battery', 'block_heater',
    'racor_filter', 'additional_parts'
  )),
  constraint asset_parts_role_valid check (role in ('none', 'primary', 'secondary')),
  constraint asset_parts_quantity_not_negative check (quantity >= 0)
);

create index if not exists idx_asset_parts_generator
  on public.asset_parts (tenant_id, equipment_key);

drop trigger if exists trg_asset_parts_updated_at on public.asset_parts;
create trigger trg_asset_parts_updated_at
  before update on public.asset_parts
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Job material lines
-- ---------------------------------------------------------------------------
create table if not exists public.job_material_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  job_type text not null,
  -- Text, not uuid: inspection ids are strings on the device.
  job_id text not null,
  equipment_key text not null default '',

  slot_type text not null,
  role text not null default 'none',
  sort_order integer not null default 0,

  part_number text not null default '',
  part_name text not null default '',
  manufacturer text not null default '',
  quantity integer not null default 1,
  date_used date,
  notes text not null default '',

  -- Set on an inspection: this part is due and the follow-up job needs it.
  needs_replacement boolean not null default false,
  -- listed | reserved | issued | used | returned | cancelled. Phase A only
  -- writes 'listed'; the rest are for the inventory phases.
  status text not null default 'listed',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint job_material_lines_job_type_valid
    check (job_type in ('inspection', 'maintenance', 'work_order')),
  constraint job_material_lines_slot_valid check (slot_type in (
    'air_filter', 'fuel_filter', 'oil_filter', 'lube_filter',
    'fuel_water_separator', 'coolant_filter', 'battery', 'block_heater',
    'racor_filter', 'additional_parts'
  )),
  constraint job_material_lines_role_valid
    check (role in ('none', 'primary', 'secondary')),
  constraint job_material_lines_status_valid check (status in (
    'listed', 'reserved', 'issued', 'used', 'returned', 'cancelled'
  )),
  constraint job_material_lines_quantity_not_negative check (quantity >= 0)
);

create index if not exists idx_job_material_lines_job
  on public.job_material_lines (tenant_id, job_type, job_id);
create index if not exists idx_job_material_lines_part
  on public.job_material_lines (tenant_id, upper(part_number))
  where length(trim(part_number)) > 0;

drop trigger if exists trg_job_material_lines_updated_at
  on public.job_material_lines;
create trigger trg_job_material_lines_updated_at
  before update on public.job_material_lines
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Row-level security
-- ---------------------------------------------------------------------------
alter table public.asset_parts enable row level security;
alter table public.job_material_lines enable row level security;

-- Nobody signed out may touch either table.
revoke all on public.asset_parts from anon;
revoke all on public.job_material_lines from anon;

-- Generator profile: every member can read it; only admin, supervisor and
-- dispatcher change it (a technician proposes a change to a supervisor).
drop policy if exists asset_parts_read on public.asset_parts;
create policy asset_parts_read on public.asset_parts
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists asset_parts_insert on public.asset_parts;
create policy asset_parts_insert on public.asset_parts
  for insert to authenticated
  with check (public.can_manage_tenant_work(tenant_id));

drop policy if exists asset_parts_update on public.asset_parts;
create policy asset_parts_update on public.asset_parts
  for update to authenticated
  using (public.can_manage_tenant_work(tenant_id))
  with check (public.can_manage_tenant_work(tenant_id));

drop policy if exists asset_parts_delete on public.asset_parts;
create policy asset_parts_delete on public.asset_parts
  for delete to authenticated
  using (public.can_manage_tenant_work(tenant_id));

-- Job lines: a technician records what they found and used, so any member may
-- write them; the tenant boundary is the guard, as for the inspections table.
drop policy if exists job_material_lines_read on public.job_material_lines;
create policy job_material_lines_read on public.job_material_lines
  for select to authenticated
  using (public.is_tenant_member(tenant_id));

drop policy if exists job_material_lines_insert on public.job_material_lines;
create policy job_material_lines_insert on public.job_material_lines
  for insert to authenticated
  with check (public.is_tenant_member(tenant_id));

drop policy if exists job_material_lines_update on public.job_material_lines;
create policy job_material_lines_update on public.job_material_lines
  for update to authenticated
  using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

drop policy if exists job_material_lines_delete on public.job_material_lines;
create policy job_material_lines_delete on public.job_material_lines
  for delete to authenticated
  using (public.is_tenant_member(tenant_id));

commit;
