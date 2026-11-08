-- Stale-write guard: an old offline edit must not overwrite a newer one.
--
-- Today sync is last-write-wins by ARRIVAL time. A tablet that was offline for a
-- day uploads its queued edit and silently replaces what a dispatcher changed
-- an hour ago.
--
-- How updated_at works here (read before changing anything):
--   * The app upserts these tables WITH a client `updated_at` (the time of the
--     edit on the device).
--   * public.set_updated_at() (BEFORE UPDATE) then overwrites updated_at with
--     now(), so the STORED value is the server time of the last accepted write.
--   * So in a BEFORE UPDATE trigger, OLD.updated_at is "when the server last
--     accepted a change" and NEW.updated_at is "when this edit was made on the
--     device". If the edit is OLDER than the stored change, it is stale.
--
-- This migration adds public.reject_stale_update(): a BEFORE UPDATE row trigger
-- that skips such an update. It is attached as trg_00_reject_stale, which sorts
-- before trg_*_updated_at (Postgres fires same-event triggers alphabetically),
-- so it sees the client time before set_updated_at() overwrites it.
--
-- Differences from the plain "return OLD" idea, on purpose:
--   * It returns NULL (skip this row's update) instead of OLD. Returning OLD
--     would still run the later set_updated_at() trigger, which would bump
--     updated_at to now() for an update that changed nothing, and would make
--     audit triggers log a no-op. For an upsert (INSERT .. ON CONFLICT DO
--     UPDATE) a skipped row is not an error, so the app's sync queue sees
--     success and drops the operation instead of retrying it forever.
--   * It allows a GRACE of 2 minutes: the edit counts as stale only when it is
--     more than 2 minutes older than the stored time. Without it, two
--     quick edits from one device would race their own network latency (edit 2
--     is stamped before edit 1 is stored) and a device clock a few seconds
--     slow would lose edits. Change `grace` below if you want it tighter.
--   Known limit: a device clock that is wrong by more than the grace can have
--   edits skipped after another write to the same row. A client-side
--   `client_updated_at` column (compare client to client) would remove that;
--   not done here to avoid touching every mapper.
--
-- The skipped edit raises a NOTICE (visible in the Postgres logs).
--
-- Attached to (rows edited as WHOLE RECORDS with a client updated_at, where an
-- older full copy replacing a newer one is wrong):
--   parts_catalog, inventory_locations, vendors, purchase_orders,
--   profile_change_requests, vehicle_inspections
--
-- NOT attached, on purpose:
--   stock_movements, part_prices, work_order_events, audit tables
--                      append-only ledgers; a late row is still a valid row
--   asset_parts, job_material_lines, purchase_order_lines
--                      the app sends no updated_at (set_updated_at() or
--                      nothing sets it); nothing to compare
--   inspections        has its own client_updated_at handling
--   fleet_vehicles, vehicle_maintenance_checks, vehicle_assets, work_orders,
--   equipment, schedule_tasks
--                      send a client updated_at too, but are also changed by
--                      server-side triggers or several roles; candidates for a
--                      later migration once the first six are proven
--
-- profile_change_requests note: approve_profile_change() updates the row
-- without touching updated_at (NEW = OLD there), so it is never judged stale;
-- a technician's late "withdraw" queued before the approval IS skipped, which
-- is right.
--
-- Idempotent: safe to run more than once.

begin;

create or replace function public.reject_stale_update()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
declare
  grace constant interval := interval '2 minutes';
begin
  if new.updated_at is not null
     and old.updated_at is not null
     and new.updated_at < old.updated_at - grace then
    raise notice 'reject_stale_update: skipped stale % on %.% (incoming %, stored %)',
      tg_op, tg_table_schema, tg_table_name, new.updated_at, old.updated_at;
    return null;
  end if;
  return new;
end;
$$;

revoke all on function public.reject_stale_update() from public, anon, authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'parts_catalog',
    'inventory_locations',
    'vendors',
    'purchase_orders',
    'profile_change_requests',
    'vehicle_inspections'
  ]
  loop
    if to_regclass('public.' || t) is not null then
      execute format('drop trigger if exists trg_00_reject_stale on public.%I', t);
      execute format(
        'create trigger trg_00_reject_stale before update on public.%I '
        'for each row execute function public.reject_stale_update()', t);
    end if;
  end loop;
end $$;

commit;
