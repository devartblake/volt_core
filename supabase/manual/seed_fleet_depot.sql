-- Create the depot A&S Electric's vehicles live in, and attach the existing
-- fleet to it.
--
-- A depot is the tenant's OWN yard. It is deliberately not a row in
-- public.sites, which holds customers' service locations — see §1 of the
-- vehicle_asset_checks migration.
--
-- HOW TO RUN
--   1. Replace <TENANT_ID> below with the tenant's uuid.
--   2. Run as an admin of that tenant (fleet_depots_write requires the role).
--
-- The address is the one printed on the company letterhead of the paper
-- receipt. Correct it here if the yard is somewhere other than the office.
--
-- With exactly one depot, the vehicle form states it rather than offering a
-- dropdown of one, and selects it automatically. Add a second row and the
-- field turns into a chooser on its own — no code change.

begin;

insert into public.fleet_depots (tenant_id, name, address)
values (
  '<TENANT_ID>'::uuid,
  'Brooklyn Yard',
  '952 Flushing Ave Suite #3, Brooklyn NY 11206'
)
on conflict do nothing;

-- Attach every vehicle that has no depot yet. Safe to re-run: vehicles already
-- pointing somewhere are left alone.
update public.fleet_vehicles v
   set depot_id = d.id
  from public.fleet_depots d
 where d.tenant_id = '<TENANT_ID>'::uuid
   and lower(trim(d.name)) = 'brooklyn yard'
   and v.tenant_id = d.tenant_id
   and v.depot_id is null;

commit;
