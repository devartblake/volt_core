-- Inventory: vendors and the prices paid to them.
--
--   vendors       companies parts are bought from
--   part_prices   append-only price history: what a vendor charged (or quoted)
--                 for a part on a date; the newest row per vendor is the
--                 current price
--
-- Prices are company costs, so only admins can read or write either table.
-- Run once in the Supabase SQL editor.

begin;

create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  name text not null,
  contact_name text not null default '',
  phone text not null default '',
  email text not null default '',
  account_number text not null default '',
  notes text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint vendors_name_not_blank check (length(trim(name)) > 0)
);

-- One vendor per name per company, ignoring case and punctuation.
create unique index if not exists idx_vendors_name
  on public.vendors (
    tenant_id,
    lower(regexp_replace(name, '[^A-Za-z0-9]', '', 'g'))
  );

drop trigger if exists trg_vendors_updated_at on public.vendors;
create trigger trg_vendors_updated_at
  before update on public.vendors
  for each row execute function public.set_updated_at();

create table if not exists public.part_prices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  part_id uuid not null references public.parts_catalog(id) on delete cascade,
  vendor_id uuid not null references public.vendors(id) on delete restrict,
  -- Price of one unit, in cents.
  unit_price_cents integer not null,
  kind text not null default 'paid',
  vendor_part_number text not null default '',
  priced_on date not null default current_date,
  note text not null default '',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint part_prices_positive check (unit_price_cents > 0),
  constraint part_prices_kind_valid check (kind in ('paid', 'quote'))
);

create index if not exists idx_part_prices_part
  on public.part_prices (tenant_id, part_id, priced_on desc);
create index if not exists idx_part_prices_vendor
  on public.part_prices (vendor_id);

alter table public.vendors enable row level security;
alter table public.part_prices enable row level security;

revoke all on public.vendors from anon;
revoke all on public.part_prices from anon;

drop policy if exists vendors_admin on public.vendors;
create policy vendors_admin on public.vendors
  for all to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

drop policy if exists part_prices_admin on public.part_prices;
create policy part_prices_admin on public.part_prices
  for all to authenticated
  using (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]))
  with check (public.has_tenant_role(tenant_id, array['admin']::public.app_role[]));

commit;
