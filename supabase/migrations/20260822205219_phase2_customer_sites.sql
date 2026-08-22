-- Voltcore FieldOps Phase 2: tenant-owned customers and customer sites.
--
-- The pre-existing `sites` table remains the canonical service-location
-- record. This migration makes a site optionally owned by a customer and
-- prevents a tenant from attaching its sites, inspections, jobs, or assets to
-- a service site belonging to another tenant.
--
-- Existing sites remain valid with customer_id = NULL. They are deliberately
-- not guessed or bulk-assigned to a customer.

begin;

-- ---------------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------------

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  name text not null,
  legal_name text not null default '',
  primary_contact_name text not null default '',
  primary_contact_email text not null default '',
  primary_contact_phone text not null default '',
  billing_address text not null default '',
  notes text not null default '',
  is_active boolean not null default true,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customers_name_not_blank check (length(trim(name)) > 0),
  constraint customers_tenant_name_unique unique (tenant_id, name),
  constraint customers_tenant_id_id_unique unique (tenant_id, id)
);

create index if not exists idx_customers_tenant_active_name
  on public.customers (tenant_id, is_active, name);

drop trigger if exists trg_customers_updated_at on public.customers;
create trigger trg_customers_updated_at
  before update on public.customers
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Customer-to-site ownership and tenant-consistent site links.
-- ---------------------------------------------------------------------------

alter table public.sites
  add column if not exists customer_id uuid;

create unique index if not exists idx_sites_tenant_id_id
  on public.sites (tenant_id, id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'sites_customer_tenant_fk'
      and conrelid = 'public.sites'::regclass
  ) then
    alter table public.sites
      add constraint sites_customer_tenant_fk
      foreign key (tenant_id, customer_id)
      references public.customers (tenant_id, id)
      on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'equipment_tenant_site_fk'
      and conrelid = 'public.equipment'::regclass
  ) then
    alter table public.equipment
      add constraint equipment_tenant_site_fk
      foreign key (tenant_id, site_id)
      references public.sites (tenant_id, id)
      on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'inspections_tenant_site_fk'
      and conrelid = 'public.inspections'::regclass
  ) then
    alter table public.inspections
      add constraint inspections_tenant_site_fk
      foreign key (tenant_id, site_id)
      references public.sites (tenant_id, id)
      on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'maintenance_jobs_tenant_site_fk'
      and conrelid = 'public.maintenance_jobs'::regclass
  ) then
    alter table public.maintenance_jobs
      add constraint maintenance_jobs_tenant_site_fk
      foreign key (tenant_id, site_id)
      references public.sites (tenant_id, id)
      on delete restrict;
  end if;
end $$;

create index if not exists idx_sites_tenant_customer
  on public.sites (tenant_id, customer_id)
  where customer_id is not null;

-- ---------------------------------------------------------------------------
-- Data API grants and RLS
--
-- Field technicians may read the customer/site directory for their active
-- tenant. Customer and site changes are restricted to dispatch, supervisory,
-- and administrator roles. Deletes are intentionally not granted: archival
-- uses is_active so historic work retains its customer/site reference.
-- ---------------------------------------------------------------------------

revoke all on public.customers from anon, authenticated;
grant select, insert, update on public.customers to authenticated;

alter table public.customers enable row level security;

drop policy if exists customers_read on public.customers;
create policy customers_read on public.customers
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

drop policy if exists customers_manage on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
create policy customers_insert on public.customers
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));
create policy customers_update on public.customers
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

-- Earlier schema setup could leave broad anon table grants in place. Keep the
-- established RLS semantics, but make this directory explicitly unavailable
-- to anonymous requests and scope its policies to authenticated sessions.
revoke all on public.sites from anon, authenticated;
grant select, insert, update on public.sites to authenticated;

drop policy if exists sites_read on public.sites;
create policy sites_read on public.sites
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

drop policy if exists sites_manage on public.sites;
drop policy if exists sites_write on public.sites;
drop policy if exists sites_insert on public.sites;
drop policy if exists sites_update on public.sites;
create policy sites_insert on public.sites
  for insert to authenticated
  with check ((select public.can_manage_tenant_work(tenant_id)));
create policy sites_update on public.sites
  for update to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));

commit;

-- No data backfill is included. Assign each existing site to a customer only
-- after the tenant verifies the commercial relationship:
--
-- update public.sites
--    set customer_id = '<CUSTOMER_UUID>'
--  where id = '<SITE_UUID>'
--    and tenant_id = '<TENANT_UUID>'
--    and customer_id is null;
