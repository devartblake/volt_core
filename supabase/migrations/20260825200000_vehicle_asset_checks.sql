-- Fleet, phase 4: the signed asset receipt.
--
-- This is the migration that replaces the paper. Everything else in the fleet
-- module is a record of what exists; this is a record of what somebody agreed
-- to, which is a different kind of data and has to be treated as such:
--
--   * the clause text is versioned and never rewritten in place, so a stored
--     signature can always be shown next to the exact words it was given for;
--   * a finalised receipt is immutable, enforced by trigger rather than by
--     hoping the client behaves;
--   * every line carries a SNAPSHOT of the tool's name and part number, so
--     renaming a catalog entry next year does not silently rewrite what a
--     technician signed for last year.
--
-- Also here, because phase 4 is the first time either matters:
--   * fleet_depots — a vehicle lives somewhere, and that somewhere is A&S's
--     own yard, not a customer `site`. See §1 below.
--   * work_orders.vehicle_id / asset_check_line_id — the trail from "the
--     ladder is missing" to the work order dispatch raises about it.

begin;

-- ---------------------------------------------------------------------------
-- 1. Depots
-- ---------------------------------------------------------------------------
-- NOT public.sites. `sites` is a CUSTOMER's service location — where work is
-- performed — and inspections, work orders and form responses all use site_id
-- with that meaning. A depot is the opposite end of the journey: the yard the
-- van sleeps in, owned by the tenant. Reusing site_id would put A&S's own
-- garage in the customer list and make "everything at this site" quietly
-- include vehicle records.
create table if not exists public.fleet_depots (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  name text not null,
  address text not null default '',
  notes text not null default '',
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,

  constraint fleet_depots_name_not_blank check (length(trim(name)) > 0),
  constraint fleet_depots_tenant_id_id_unique unique (tenant_id, id)
);

create unique index if not exists idx_fleet_depots_name
  on public.fleet_depots (tenant_id, lower(trim(name)));

drop trigger if exists trg_fleet_depots_updated_at on public.fleet_depots;
create trigger trg_fleet_depots_updated_at
  before update on public.fleet_depots
  for each row execute function public.set_updated_at();

-- Nullable, and left null for every vehicle that already exists. A&S runs one
-- depot today, so backfilling by guesswork would buy nothing and a NOT NULL
-- would fail the migration on live data.
alter table public.fleet_vehicles
  add column if not exists depot_id uuid;

-- Composite FK, matching the customer/site/asset pattern in the work_orders
-- migration: it makes a cross-tenant depot reference impossible rather than
-- merely unlikely.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'fleet_vehicles_tenant_depot_fk'
      and conrelid = 'public.fleet_vehicles'::regclass
  ) then
    alter table public.fleet_vehicles
      add constraint fleet_vehicles_tenant_depot_fk
      foreign key (tenant_id, depot_id)
      references public.fleet_depots (tenant_id, id) on delete restrict;
  end if;
end $$;

create index if not exists idx_fleet_vehicles_depot
  on public.fleet_vehicles (tenant_id, depot_id)
  where depot_id is not null;

-- Needed by the composite foreign keys added further down. The fleet_vehicles
-- migration never declared one because nothing referenced a vehicle yet.
create unique index if not exists idx_fleet_vehicles_tenant_id_id
  on public.fleet_vehicles (tenant_id, id);

-- ---------------------------------------------------------------------------
-- 2. Disclaimer versions
-- ---------------------------------------------------------------------------
-- The receipt is a signed acceptance of five liability clauses. If that wording
-- is ever revised, every signature already stored was given against the OLD
-- text — so the record has to say which version each person signed, and the
-- text of a published version must never change.
--
-- That immutability is expressed by what is NOT here: `authenticated` is
-- granted select and insert, and nothing else. There is no update policy and
-- no delete policy, because publishing a revision means inserting version N+1,
-- not editing version N. A column nobody can write cannot drift.
create table if not exists public.fleet_disclaimers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- Monotonic per tenant. Receipts store this number, not a foreign key, so a
  -- receipt stays readable even if a row is ever removed by an operator.
  version integer not null,

  title text not null default 'Asset Disclaimer',

  -- The sentence above the numbered list.
  intro text not null default '',

  -- [{"heading": "Responsibility", "body": "The employee assumes..."}, ...]
  -- Structured rather than one blob so the modal and the PDF can render the
  -- bold heading exactly as the paper prints it, without parsing prose.
  clauses jsonb not null default '[]'::jsonb,

  -- The sentence below the list, above the signature line.
  closing text not null default '',

  published_at timestamptz not null default now(),
  published_by uuid references auth.users(id) on delete set null,

  constraint fleet_disclaimers_version_positive check (version > 0),
  constraint fleet_disclaimers_clauses_is_array
    check (jsonb_typeof(clauses) = 'array'),
  constraint fleet_disclaimers_has_clauses
    check (jsonb_array_length(clauses) > 0),
  constraint fleet_disclaimers_tenant_version_unique unique (tenant_id, version)
);

-- ---------------------------------------------------------------------------
-- 3. Asset check — the receipt header
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_asset_checks (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  vehicle_id uuid not null,

  checked_at timestamptz not null default now(),

  -- The driver. user_id when they are an app user; the printed name always,
  -- because the paper prints a name and a receipt that cannot be read without
  -- a database lookup is worse than the paper it replaces.
  operator_user_id uuid references auth.users(id) on delete set null,
  operator_name text not null default '',

  -- Second person in the van. Frequently a helper with no app account, so this
  -- is a name and nothing else.
  co_operator_name text not null default '',

  dispatcher_user_id uuid references auth.users(id) on delete set null,
  dispatcher_name text not null default '',

  -- Signatures are stored objects, not bytes in a column: a base64 PNG per
  -- receipt would bloat every sync payload that touches this table.
  operator_signature_path text,
  operator_signed_at timestamptz,

  -- Second verification. The paper has one signature line; requiring dispatch
  -- to counter-sign is a deliberate addition, not a transcription.
  dispatcher_signature_path text,
  dispatcher_signed_at timestamptz,

  -- Which wording the operator was shown and accepted, and when they accepted
  -- it. Recorded separately from the signature because the modal is presented
  -- before the pen is offered.
  disclaimer_version integer not null,
  disclaimer_accepted_at timestamptz,

  notes text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint vehicle_asset_checks_tenant_id_id_unique unique (tenant_id, id),

  -- A signature without a timestamp, or a timestamp without a signature, is a
  -- half-written record that later code would have to guess about.
  constraint vehicle_asset_checks_operator_signature_paired check (
    (operator_signature_path is null) = (operator_signed_at is null)
  ),
  constraint vehicle_asset_checks_dispatcher_signature_paired check (
    (dispatcher_signature_path is null) = (dispatcher_signed_at is null)
  ),

  -- Dispatch counter-signs what the driver already signed. The reverse order
  -- would mean verifying an unsigned receipt.
  constraint vehicle_asset_checks_countersign_order check (
    dispatcher_signed_at is null or operator_signed_at is not null
  ),

  -- Nobody signs before being shown the terms.
  constraint vehicle_asset_checks_disclaimer_before_signature check (
    operator_signed_at is null or disclaimer_accepted_at is not null
  )
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'vehicle_asset_checks_tenant_vehicle_fk'
      and conrelid = 'public.vehicle_asset_checks'::regclass
  ) then
    alter table public.vehicle_asset_checks
      add constraint vehicle_asset_checks_tenant_vehicle_fk
      foreign key (tenant_id, vehicle_id)
      references public.fleet_vehicles (tenant_id, id) on delete cascade;
  end if;
end $$;

-- Deliberately NO unique index on (vehicle_id, date). Vans get dispatched
-- twice in a day and drivers swap mid-shift; a uniqueness rule here would
-- surface as a 23505 in a yard with no signal, which is the worst possible
-- place to hit one.
create index if not exists idx_vehicle_asset_checks_vehicle
  on public.vehicle_asset_checks (tenant_id, vehicle_id, checked_at desc);

create index if not exists idx_vehicle_asset_checks_operator
  on public.vehicle_asset_checks (tenant_id, operator_user_id, checked_at desc)
  where operator_user_id is not null;

-- Dispatch's queue: signed by the driver, not yet counter-signed.
create index if not exists idx_vehicle_asset_checks_awaiting_countersign
  on public.vehicle_asset_checks (tenant_id, checked_at desc)
  where operator_signed_at is not null and dispatcher_signed_at is null;

drop trigger if exists trg_vehicle_asset_checks_updated_at
  on public.vehicle_asset_checks;
create trigger trg_vehicle_asset_checks_updated_at
  before update on public.vehicle_asset_checks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 4. Asset check lines — one row per tool, exactly as the paper prints it
-- ---------------------------------------------------------------------------
create table if not exists public.vehicle_asset_check_lines (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  check_id uuid not null
    references public.vehicle_asset_checks(id) on delete cascade,

  -- Nullable on purpose. The asset may be retired or deleted years after the
  -- receipt was signed; the line must survive that, which is what the snapshot
  -- columns below are for.
  vehicle_asset_id uuid references public.vehicle_assets(id) on delete set null,

  -- SNAPSHOT. Not a join. What the tool was called on the day it was signed
  -- for, so correcting a catalog typo in 2027 does not retroactively edit a
  -- 2026 receipt.
  asset_name text not null,
  part_number text not null default '',
  serial_number text not null default '',

  quantity integer not null default 1,

  -- fmc | nmc, the same two values as vehicle_assets.readiness.
  readiness text not null default 'fmc',
  is_missing boolean not null default false,
  reason text not null default '',

  -- Keeps the printed order stable across devices and reprints.
  sort_index integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint vehicle_asset_check_lines_name_not_blank
    check (length(trim(asset_name)) > 0),
  constraint vehicle_asset_check_lines_readiness_valid
    check (readiness in ('fmc', 'nmc')),
  constraint vehicle_asset_check_lines_quantity_positive check (quantity > 0),

  -- "Missing" with no reason is the one thing on this form that is useless
  -- without the next column. The UI blocks it too; this is what makes the rule
  -- true rather than merely enforced-if-you-use-our-client.
  constraint vehicle_asset_check_lines_missing_needs_reason
    check (not is_missing or length(trim(reason)) > 0)
);

create index if not exists idx_vehicle_asset_check_lines_check
  on public.vehicle_asset_check_lines (check_id, sort_index);

create index if not exists idx_vehicle_asset_check_lines_asset
  on public.vehicle_asset_check_lines (tenant_id, vehicle_asset_id)
  where vehicle_asset_id is not null;

create index if not exists idx_vehicle_asset_check_lines_exceptions
  on public.vehicle_asset_check_lines (tenant_id, check_id)
  where is_missing or readiness <> 'fmc';

drop trigger if exists trg_vehicle_asset_check_lines_updated_at
  on public.vehicle_asset_check_lines;
create trigger trg_vehicle_asset_check_lines_updated_at
  before update on public.vehicle_asset_check_lines
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. Immutability once counter-signed
-- ---------------------------------------------------------------------------
-- A receipt both parties have signed is evidence. Editing it afterwards would
-- change what somebody is on record as having agreed to.
--
-- THE SUBTLETY: the client writes through a durable offline outbox that retries
-- with UPSERTs. A retry after a crash re-sends a row that is already finalised,
-- and a naive "reject every update" trigger would reject that identical row
-- forever — jamming the queue behind a write that can never succeed, which is
-- exactly the failure this project already spent a week diagnosing once.
--
-- So the rule is: reject updates that CHANGE something. An identical re-send is
-- allowed through untouched.
create or replace function public.reject_finalized_asset_check_edit()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    if old.dispatcher_signed_at is not null then
      raise exception
        'Receipt % is counter-signed and cannot be deleted.', old.id
        using errcode = 'restrict_violation';
    end if;
    return old;
  end if;

  if old.dispatcher_signed_at is null then
    return new;
  end if;

  -- Idempotent re-send from the sync outbox: nothing of substance differs, so
  -- let it land rather than jamming the queue.
  if to_jsonb(new) - 'updated_at' = to_jsonb(old) - 'updated_at' then
    return new;
  end if;

  raise exception 'Receipt % is counter-signed and cannot be modified.', old.id
    using errcode = 'restrict_violation';
end;
$$;

create or replace function public.reject_finalized_asset_check_line_edit()
returns trigger
language plpgsql
as $$
declare
  finalized timestamptz;
  target uuid;
begin
  target := case when tg_op = 'DELETE' then old.check_id else new.check_id end;

  select c.dispatcher_signed_at into finalized
    from public.vehicle_asset_checks c
   where c.id = target;

  if finalized is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'UPDATE'
     and to_jsonb(new) - 'updated_at' = to_jsonb(old) - 'updated_at' then
    return new;
  end if;

  raise exception
    'Receipt % is counter-signed; its lines cannot be changed.', target
    using errcode = 'restrict_violation';
end;
$$;

drop trigger if exists trg_vehicle_asset_checks_immutable
  on public.vehicle_asset_checks;
create trigger trg_vehicle_asset_checks_immutable
  before update or delete on public.vehicle_asset_checks
  for each row execute function public.reject_finalized_asset_check_edit();

drop trigger if exists trg_vehicle_asset_check_lines_immutable
  on public.vehicle_asset_check_lines;
create trigger trg_vehicle_asset_check_lines_immutable
  before insert or update or delete on public.vehicle_asset_check_lines
  for each row execute function public.reject_finalized_asset_check_line_edit();

-- ---------------------------------------------------------------------------
-- 6. Work order trail
-- ---------------------------------------------------------------------------
-- Dispatch raises a work order from a missing tool. Without these two columns
-- the only link would be the words "Work Van B" typed into the title, which is
-- not a link — it is a hope that nobody renames the van.
alter table public.work_orders
  add column if not exists vehicle_id uuid;
alter table public.work_orders
  add column if not exists asset_check_line_id uuid;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'work_orders_tenant_vehicle_fk'
      and conrelid = 'public.work_orders'::regclass
  ) then
    alter table public.work_orders add constraint work_orders_tenant_vehicle_fk
      foreign key (tenant_id, vehicle_id)
      references public.fleet_vehicles (tenant_id, id) on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'work_orders_asset_check_line_fk'
      and conrelid = 'public.work_orders'::regclass
  ) then
    -- set null, not restrict: losing the receipt line must never make the work
    -- order undeletable or block a tenant teardown.
    alter table public.work_orders add constraint work_orders_asset_check_line_fk
      foreign key (asset_check_line_id)
      references public.vehicle_asset_check_lines (id) on delete set null;
  end if;
end $$;

create index if not exists idx_work_orders_vehicle
  on public.work_orders (tenant_id, vehicle_id)
  where vehicle_id is not null;

-- ---------------------------------------------------------------------------
-- 7. RLS
-- ---------------------------------------------------------------------------
-- A policy per operation, and the grant. A read-only policy set is silent until
-- the first save — see the note in the fleet_vehicles migration.

alter table public.fleet_depots enable row level security;
alter table public.fleet_disclaimers enable row level security;
alter table public.vehicle_asset_checks enable row level security;
alter table public.vehicle_asset_check_lines enable row level security;

grant select, insert, update, delete on public.fleet_depots to authenticated;
-- select and insert ONLY. See §2: a published version is never edited.
grant select, insert on public.fleet_disclaimers to authenticated;
grant select, insert, update, delete
  on public.vehicle_asset_checks to authenticated;
grant select, insert, update, delete
  on public.vehicle_asset_check_lines to authenticated;

-- Depots: everyone reads (a driver's receipt names one), admin curates.
drop policy if exists fleet_depots_read on public.fleet_depots;
create policy fleet_depots_read
  on public.fleet_depots
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

drop policy if exists fleet_depots_write on public.fleet_depots;
create policy fleet_depots_write
  on public.fleet_depots
  for all to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  )
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

-- Disclaimers: every member must be able to read what they are being asked to
-- sign, offline and on their own device. Only an admin publishes a revision.
drop policy if exists fleet_disclaimers_read on public.fleet_disclaimers;
create policy fleet_disclaimers_read
  on public.fleet_disclaimers
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

drop policy if exists fleet_disclaimers_publish on public.fleet_disclaimers;
create policy fleet_disclaimers_publish
  on public.fleet_disclaimers
  for insert to authenticated
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

-- Receipts follow the vehicle, like the assets on it: a technician sees the
-- receipts for the van they are stationed to, which are the ones they signed.
drop policy if exists vehicle_asset_checks_read on public.vehicle_asset_checks;
create policy vehicle_asset_checks_read
  on public.vehicle_asset_checks
  for select to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_asset_checks.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- Unlike vehicle_assets, the driver WRITES here. That is the whole point: they
-- sign for the van. Dispatch does the data entry, the driver signs, dispatch
-- counter-signs — all three are writes to this row.
drop policy if exists vehicle_asset_checks_insert on public.vehicle_asset_checks;
create policy vehicle_asset_checks_insert
  on public.vehicle_asset_checks
  for insert to authenticated
  with check (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_asset_checks.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- Immutability after counter-signing is the trigger's job, not this policy's.
-- Expressing it here would turn an idempotent outbox retry into a permanent
-- 42501 instead of a no-op.
drop policy if exists vehicle_asset_checks_update on public.vehicle_asset_checks;
create policy vehicle_asset_checks_update
  on public.vehicle_asset_checks
  for update to authenticated
  using (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_asset_checks.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  )
  with check (
    (select public.can_manage_tenant_work(tenant_id))
    or exists (
      select 1
        from public.fleet_vehicles v
       where v.id = vehicle_id
         and v.tenant_id = vehicle_asset_checks.tenant_id
         and v.assigned_to_user_id = (select auth.uid())
    )
  );

-- Deleting a receipt is dispatch's call, and only ever a draft one.
drop policy if exists vehicle_asset_checks_delete on public.vehicle_asset_checks;
create policy vehicle_asset_checks_delete
  on public.vehicle_asset_checks
  for delete to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)));

-- Lines inherit their header's visibility. Written as EXISTS against the parent
-- rather than repeating the vehicle join, so the two can never disagree about
-- who may see a receipt.
drop policy if exists vehicle_asset_check_lines_read
  on public.vehicle_asset_check_lines;
create policy vehicle_asset_check_lines_read
  on public.vehicle_asset_check_lines
  for select to authenticated
  using (
    exists (
      select 1
        from public.vehicle_asset_checks c
       where c.id = check_id
         and c.tenant_id = vehicle_asset_check_lines.tenant_id
    )
  );

drop policy if exists vehicle_asset_check_lines_insert
  on public.vehicle_asset_check_lines;
create policy vehicle_asset_check_lines_insert
  on public.vehicle_asset_check_lines
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.vehicle_asset_checks c
       where c.id = check_id
         and c.tenant_id = vehicle_asset_check_lines.tenant_id
    )
  );

drop policy if exists vehicle_asset_check_lines_update
  on public.vehicle_asset_check_lines;
create policy vehicle_asset_check_lines_update
  on public.vehicle_asset_check_lines
  for update to authenticated
  using (
    exists (
      select 1
        from public.vehicle_asset_checks c
       where c.id = check_id
         and c.tenant_id = vehicle_asset_check_lines.tenant_id
    )
  )
  with check (
    exists (
      select 1
        from public.vehicle_asset_checks c
       where c.id = check_id
         and c.tenant_id = vehicle_asset_check_lines.tenant_id
    )
  );

drop policy if exists vehicle_asset_check_lines_delete
  on public.vehicle_asset_check_lines;
create policy vehicle_asset_check_lines_delete
  on public.vehicle_asset_check_lines
  for delete to authenticated
  using (
    exists (
      select 1
        from public.vehicle_asset_checks c
       where c.id = check_id
         and c.tenant_id = vehicle_asset_check_lines.tenant_id
         and (select public.can_manage_tenant_work(c.tenant_id))
    )
  );

commit;
