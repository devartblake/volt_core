-- Truck stock and "mark used".
-- See docs/materials_and_inventory_design.md (locations, decision 4).
--
--   1. inventory_locations: a truck can link to a fleet vehicle and to the
--      technician it is assigned to.
--   2. inventory_movements: new reason 'transfer' (two rows: negative at the
--      source location, positive at the destination).
--   3. inventory_stock: transfers count towards on hand per location.
--   4. job_material_lines: used_movement_id, the ledger entry made by
--      "Mark used", so it is only ever recorded once.
--   5. Insert policy: supervisors and dispatchers may also record transfers;
--      technicians may record issue / return for a job (their own usage).
--
-- Safe to run more than once.

begin;

-- ---------------------------------------------------------------------------
-- 1. Truck links
-- ---------------------------------------------------------------------------
alter table public.inventory_locations
  add column if not exists vehicle_id uuid
    references public.fleet_vehicles(id) on delete set null;
alter table public.inventory_locations
  add column if not exists assigned_user_id uuid
    references auth.users(id) on delete set null;

create index if not exists idx_inventory_locations_assigned
  on public.inventory_locations (tenant_id, assigned_user_id)
  where assigned_user_id is not null;

-- ---------------------------------------------------------------------------
-- 2. Transfer reason
-- ---------------------------------------------------------------------------
alter table public.inventory_movements
  drop constraint if exists inventory_movements_reason_valid;
alter table public.inventory_movements
  add constraint inventory_movements_reason_valid check (reason in (
    'receive', 'adjust', 'count', 'reserve', 'release', 'issue', 'return',
    'transfer'
  ));

-- ---------------------------------------------------------------------------
-- 3. Stock view: transfers move on-hand between locations
-- ---------------------------------------------------------------------------
create or replace view public.inventory_stock
with (security_invoker = true) as
select
  p.tenant_id,
  p.id as part_id,
  m.location_id,
  coalesce(sum(m.qty_delta) filter (
    where m.reason in ('receive', 'adjust', 'count', 'issue', 'return',
                       'transfer')
  ), 0)::integer as on_hand,
  coalesce(sum(m.qty_delta) filter (where m.reason = 'reserve'), 0)::integer
    - coalesce(sum(m.qty_delta) filter (where m.reason = 'release'), 0)::integer
    as reserved
from public.parts_catalog p
join public.inventory_movements m on m.part_id = p.id
group by p.tenant_id, p.id, m.location_id;

-- ---------------------------------------------------------------------------
-- 4. "Mark used" bookkeeping on job material lines
-- ---------------------------------------------------------------------------
alter table public.job_material_lines
  add column if not exists used_movement_id uuid;

-- ---------------------------------------------------------------------------
-- 5. Who may write to the ledger
-- ---------------------------------------------------------------------------
drop policy if exists inventory_movements_insert on public.inventory_movements;
create policy inventory_movements_insert on public.inventory_movements
  for insert to authenticated
  with check (
    -- Admins: any movement.
    public.has_tenant_role(tenant_id, array['admin']::public.app_role[])
    or (
      -- Supervisors and dispatchers: job movements, and transfers between
      -- locations.
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
      -- Technicians: what they used on a job (issue) and what they put back
      -- (return), always against a named job, and only in their own name.
      public.has_tenant_role(tenant_id, array['technician']::public.app_role[])
      and reason in ('issue', 'return')
      and job_ref is not null
      and (user_id is null or user_id = auth.uid())
    )
  );

commit;
