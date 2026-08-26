-- Optional: seed the vehicle asset catalog with the tools on the current
-- paper receipt.
--
-- NOT a migration. Migrations run for every tenant; this is one tenant's tool
-- list, so it is run by hand once and edited freely afterwards.
--
-- Usage: replace the tenant id below with your own, then run the whole file in
-- the Supabase SQL editor. Safe to re-run — it matches on name and updates the
-- part number rather than inserting a duplicate.

do $$
declare
  -- ⬇️ REPLACE THIS with the tenant id these vans belong to.
  v_tenant uuid := '00000000-0000-0000-0000-000000000000';

  -- name, part number ('' where the form leaves it blank), category
  v_items text[][] := array[
    ['IDEAL 1/2" EMT BENDER',    '74-031',      'Benders'],
    ['IDEAL 3/4" EMT BENDER',    '74-003',      'Benders'],
    ['MILWAUKEE 1" EMT BENDER',  '48-22-4071',  'Benders'],
    ['IDEAL METAL FISH TAPE',    '31-056',      'Fish tape'],
    ['IDEAL PLASTIC FISH TAPE',  '31-544',      'Fish tape'],
    ['WERNER 8FT LADDER',        '6208',        'Ladders'],
    ['100FT EXTENSION CORD',     '',            'Power'],
    ['PRO TEAM BACK VACUUM SET', '',            'Cleaning'],
    ['KLEIN TOOL SIH ROD SET',   '50254',       'Rods'],
    ['PUSH CART',                '',            'Material handling']
  ];

  v_row text[];
  v_part text;
begin
  if not exists (select 1 from public.tenants where id = v_tenant) then
    raise exception
      'Tenant % does not exist. Edit v_tenant at the top of this file.',
      v_tenant;
  end if;

  foreach v_row slice 1 in array v_items loop
    v_part := nullif(btrim(v_row[2]), '');

    insert into public.vehicle_asset_catalog (tenant_id, name, part_number, category)
    values (v_tenant, v_row[1], v_part, v_row[3])
    on conflict (tenant_id, lower(btrim(name))) do update
      set part_number = excluded.part_number,
          category    = excluded.category,
          is_active   = true;
  end loop;

  raise notice 'Catalog seeded for tenant %.', v_tenant;
end $$;

-- The two Werner ladders on the paper form are ONE catalog entry and TWO
-- vehicle_assets rows. The catalog says what a tool is; the van's manifest
-- says how many of them it carries, one row each — which is what lets a
-- receipt mark one missing and the other present.
--
-- Assign them from the app: Fleet → the vehicle → Assets → Add.
