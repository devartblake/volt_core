-- Two foreign-key indexes the housekeeping migration (20261110120000) could not
-- create: an index with the same name already existed on other columns, so
-- `create index if not exists` skipped them. These use new names.
-- Idempotent. Run once in the Supabase SQL editor.

begin;

create index if not exists idx_inventory_movements_part_id
  on public.inventory_movements (part_id);

create index if not exists idx_purchase_order_lines_part_id
  on public.purchase_order_lines (part_id);

commit;
