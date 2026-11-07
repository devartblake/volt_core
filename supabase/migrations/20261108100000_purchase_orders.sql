-- Inventory: purchase orders.
--
--   purchase_orders        one order to one vendor, with a human PO number
--   purchase_order_lines   the parts on it: quantity ordered, quantity
--                          received so far, and the agreed unit price
--
-- Orders carry prices, which are company costs, so only admins can read or
-- write either table. Idempotent: safe to run more than once.

begin;

create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  po_number text not null,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  status text not null default 'draft',
  expected_on date,
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint purchase_orders_number_not_blank check (length(trim(po_number)) > 0),
  constraint purchase_orders_status_valid
    check (status in ('draft', 'sent', 'partial', 'received', 'cancelled'))
);

create unique index if not exists idx_purchase_orders_number
  on public.purchase_orders (tenant_id, po_number);
create index if not exists idx_purchase_orders_vendor
  on public.purchase_orders (vendor_id);
create index if not exists idx_purchase_orders_status
  on public.purchase_orders (tenant_id, status);

drop trigger if exists trg_purchase_orders_updated_at on public.purchase_orders;
create trigger trg_purchase_orders_updated_at
  before update on public.purchase_orders
  for each row execute function public.set_updated_at();

create table if not exists public.purchase_order_lines (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  order_id uuid not null references public.purchase_orders(id) on delete cascade,
  part_id uuid not null references public.parts_catalog(id) on delete restrict,
  qty_ordered integer not null,
  qty_received integer not null default 0,
  -- Price of one unit, in cents.
  unit_price_cents integer not null default 0,
  vendor_part_number text not null default '',
  created_at timestamptz not null default now(),
  constraint purchase_order_lines_ordered_positive check (qty_ordered > 0),
  constraint purchase_order_lines_received_nonneg check (qty_received >= 0),
  constraint purchase_order_lines_price_nonneg check (unit_price_cents >= 0)
);

create index if not exists idx_purchase_order_lines_order
  on public.purchase_order_lines (order_id);
create index if not exists idx_purchase_order_lines_part
  on public.purchase_order_lines (tenant_id, part_id);

alter table public.purchase_orders enable row level security;
alter table public.purchase_order_lines enable row level security;

revoke all on public.purchase_orders from anon;
revoke all on public.purchase_order_lines from anon;

drop policy if exists purchase_orders_admin on public.purchase_orders;
create policy purchase_orders_admin on public.purchase_orders
  for all to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists purchase_order_lines_admin on public.purchase_order_lines;
create policy purchase_order_lines_admin on public.purchase_order_lines
  for all to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

commit;
