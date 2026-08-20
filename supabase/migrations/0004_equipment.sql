-- Voltcore migration 0004: the equipment registry
--
-- Until now "equipment" was derived on each device from its local inspection
-- history. That works offline but has two limits: a unit inspected on one
-- phone is invisible on another, and a generator that has never been inspected
-- cannot be tracked at all.
--
-- This table is the shared registry. The app still derives units from
-- inspections — that stays the zero-data-entry path — and upserts what it
-- derives here, so every device converges on the same list and units can also
-- be added before their first inspection.
--
-- Convergence without a conflict target: `id` is a deterministic UUIDv5 of
-- "<tenant_id>|<identity_key>", computed client-side. Two devices deriving the
-- same physical unit produce the same id, so a plain upsert merges them. The
-- unique constraint on (tenant_id, identity_key) is the backstop.
--
-- Idempotent. Run after 0003.

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- equipment
-- ---------------------------------------------------------------------------
create table if not exists public.equipment(
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- How the app decides two records are the same physical unit:
  --   'sn:<serial>'                    — preferred, serial normalised lower/trimmed
  --   'composite:<site>|<make>|<model>' — when no serial was recorded
  --   'id:<inspection id>'              — nothing identifying at all
  identity_key text not null,

  name text not null default '',
  make text not null default '',
  model text not null default '',
  serial_number text not null default '',
  voltage text not null default '',

  -- Where it was last seen, from the most recent inspection.
  location text not null default '',
  site_code text not null default '',
  site_grade text not null default '',

  -- active | inactive | maintenance | retired
  status text not null default 'active',

  last_inspection_at timestamptz,
  inspection_count integer not null default 0,

  -- Latest inspection this unit was seen on, so the app can deep-link to its
  -- nameplate. Text rather than a foreign key: inspections are created offline
  -- and may not have synced yet, and a missing link should not block the
  -- registry row.
  latest_inspection_id text,

  -- Set by hand for units entered before their first inspection.
  is_manual boolean not null default false,
  notes text,

  first_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint equipment_identity_unique unique (tenant_id, identity_key),
  constraint equipment_status_valid check (
    status in ('active', 'inactive', 'maintenance', 'retired')
  )
);

create index if not exists idx_equipment_tenant on public.equipment(tenant_id);
create index if not exists idx_equipment_serial
  on public.equipment(tenant_id, serial_number);
create index if not exists idx_equipment_last_inspection
  on public.equipment(tenant_id, last_inspection_at desc nulls last);
create index if not exists idx_equipment_status
  on public.equipment(tenant_id, status);

-- Keep updated_at honest even for writes that forget to set it.
drop trigger if exists trg_equipment_updated_at on public.equipment;
create trigger trg_equipment_updated_at
  before update on public.equipment
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- RLS — tenant members read and write their own tenant's equipment.
-- ---------------------------------------------------------------------------
alter table public.equipment enable row level security;

drop policy if exists equipment_read on public.equipment;
create policy equipment_read on public.equipment
  for select using (public.is_tenant_member(tenant_id));

drop policy if exists equipment_write on public.equipment;
create policy equipment_write on public.equipment
  for all using (public.is_tenant_member(tenant_id))
  with check (public.is_tenant_member(tenant_id));

commit;

-- ---------------------------------------------------------------------------
-- Optional backfill.
--
-- Seeds the registry from inspections already in Postgres, so a fresh install
-- sees history it never inspected locally. Safe to re-run: the same unit
-- produces the same identity_key, and existing rows are updated rather than
-- duplicated.
--
-- Note the id here is gen_random_uuid(), not the client's deterministic v5.
-- The unique (tenant_id, identity_key) constraint is what keeps a later client
-- upsert from creating a second row — it will conflict and update this one.
-- Run the backfill *or* let the clients populate it; running both is fine.
-- ---------------------------------------------------------------------------
-- with latest as (
--   select distinct on (i.tenant_id, coalesce(nullif(lower(trim(
--            i.payload->>'generator_serial')), ''),
--          'composite:' || lower(trim(coalesce(i.site_code,''))) || '|' ||
--            lower(trim(coalesce(i.payload->>'generator_make',''))) || '|' ||
--            lower(trim(coalesce(i.payload->>'generator_model','')))))
--     i.tenant_id,
--     case when nullif(trim(i.payload->>'generator_serial'), '') is not null
--          then 'sn:' || lower(trim(i.payload->>'generator_serial'))
--          else 'composite:' || lower(trim(coalesce(i.site_code,''))) || '|' ||
--               lower(trim(coalesce(i.payload->>'generator_make',''))) || '|' ||
--               lower(trim(coalesce(i.payload->>'generator_model','')))
--     end as identity_key,
--     i.id as latest_inspection_id,
--     coalesce(i.payload->>'generator_make','') as make,
--     coalesce(i.payload->>'generator_model','') as model,
--     coalesce(i.payload->>'generator_serial','') as serial_number,
--     coalesce(i.payload->>'voltage_rating','') as voltage,
--     coalesce(i.address,'') as location,
--     coalesce(i.site_code,'') as site_code,
--     coalesce(i.site_grade,'') as site_grade,
--     i.service_date
--   from public.inspections i
--   order by 1, 2, i.service_date desc
-- )
-- insert into public.equipment(
--   id, tenant_id, identity_key, name, make, model, serial_number, voltage,
--   location, site_code, site_grade, status, last_inspection_at,
--   latest_inspection_id, inspection_count)
-- select
--   gen_random_uuid(), l.tenant_id, l.identity_key,
--   nullif(trim(l.make || ' ' || l.model), ''),
--   l.make, l.model, l.serial_number, l.voltage, l.location, l.site_code,
--   l.site_grade,
--   case when lower(l.site_grade) in ('red','amber') then 'maintenance'
--        else 'active' end,
--   l.service_date, l.latest_inspection_id, 1
-- from latest l
-- on conflict (tenant_id, identity_key) do update set
--   make = excluded.make,
--   model = excluded.model,
--   serial_number = excluded.serial_number,
--   voltage = excluded.voltage,
--   location = excluded.location,
--   site_code = excluded.site_code,
--   site_grade = excluded.site_grade,
--   status = excluded.status,
--   last_inspection_at = greatest(
--     public.equipment.last_inspection_at, excluded.last_inspection_at),
--   latest_inspection_id = excluded.latest_inspection_id,
--   updated_at = now();
