-- ============================================================================
-- Voltcore / A&S Electric â COMPLETE Supabase schema (app-aligned)
-- ============================================================================
-- Single, self-contained setup for the projects database. It is a superset of
-- the consolidated v2 schema and all committed Phase 1 / Phase 2 migrations,
-- aligned
-- with what the Flutter app actually reads/writes:
--
--   * inspections           -> identity columns + `payload` jsonb
--   * maintenance_jobs       -> identity row (id == app record id)
--   * maintenance_records    -> `data` jsonb, job_id == app record id
--   * files (pdf/signature/photo) -> Storage bucket 'voltcore-files'
--   * schedule_tasks, equipment, technicians, role_assignments
--   * customers and customer-owned sites
--   * tenant-scoped work_orders and trigger-owned work_order_events
--
-- Differences vs v2 (all additive):
--   * creates the 'voltcore-files' storage bucket the app uploads to
--   * adds the RLS policies v2 left off (maintenance_records, parts,
--     attachments, nameplate_data, test_intervals, user_profiles, app_settings)
--   * work-table write policies allow any TENANT MEMBER (so field technicians
--     can create/sync offline work), deletes stay manager-only. See the tail
--     for the stricter alternative.
--   * storage.objects policies for authenticated upload/read.
--
-- This is a bootstrap artifact for a NEW VoltCore project. Apply the numbered
-- migrations to an existing project instead; do not use this file to upgrade
-- a populated database.
-- ============================================================================

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname='app_role') then
    create type public.app_role as enum ('admin','supervisor','dispatcher','technician');
  end if;
  if not exists (select 1 from pg_type where typname='work_status') then
    create type public.work_status as enum ('draft','scheduled','in_progress','completed','cancelled','archived');
  end if;
  if not exists (select 1 from pg_type where typname='project_task_type') then
    create type public.project_task_type as enum ('inspection','maintenance','manual');
  end if;
end $$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Core / tenancy
-- ---------------------------------------------------------------------------
create table if not exists public.tenants(
 id uuid primary key default gen_random_uuid(), name text not null, slug text unique not null,
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.user_profiles(
 user_id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '', email text not null default '', phone text, avatar_path text,
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.tenant_members(
 tenant_id uuid not null references public.tenants(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 role public.app_role not null, is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), primary key(tenant_id,user_id));

create table if not exists public.app_settings(
 key text primary key, value jsonb not null default '{}'::jsonb, description text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.sites(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 site_code text not null, address text not null default '', site_grade text not null default '', notes text not null default '',
 is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,site_code));

-- ---------------------------------------------------------------------------
-- Inspections (identity columns + payload jsonb)
-- ---------------------------------------------------------------------------
create table if not exists public.inspections(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 site_id uuid references public.sites(id) on delete set null, site_code text not null default '', site_grade text not null default '',
 address text not null default '', service_date timestamptz not null default now(), technician_name text not null default '',
 assigned_technician_user_id uuid references auth.users(id) on delete set null, status public.work_status not null default 'draft',
 notes text not null default '', pdf_path text not null default '', payload jsonb not null default '{}'::jsonb,
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 client_updated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.nameplate_data(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 inspection_id uuid not null unique references public.inspections(id) on delete cascade,
 data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.test_intervals(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 inspection_id uuid not null references public.inspections(id) on delete cascade, interval_index integer not null default 0,
 data jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(inspection_id,interval_index));

-- ---------------------------------------------------------------------------
-- Maintenance (job identity + record detail jsonb + parts + attachments)
-- ---------------------------------------------------------------------------
create table if not exists public.maintenance_jobs(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 site_id uuid references public.sites(id) on delete set null, inspection_id uuid references public.inspections(id) on delete set null,
 title text not null default 'Maintenance Job', site_code text not null default '', address text not null default '', technician_name text not null default '',
 assigned_technician_user_id uuid references auth.users(id) on delete set null, scheduled_date timestamptz, date_of_service timestamptz,
 status public.work_status not null default 'draft', is_completed boolean not null default false, completed_at timestamptz,
 requires_follow_up boolean not null default false, follow_up_notes text, is_archived boolean not null default false, archived_at timestamptz,
 general_notes text, created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 client_updated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.maintenance_records(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 job_id uuid not null unique references public.maintenance_jobs(id) on delete cascade, data jsonb not null default '{}'::jsonb,
 client_updated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.maintenance_parts_used(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 job_id uuid not null references public.maintenance_jobs(id) on delete cascade, category text not null, label text not null default '',
 part_number text not null default '', quantity numeric, unit text, notes text, client_updated_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.maintenance_attachments(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 job_id uuid not null references public.maintenance_jobs(id) on delete cascade, kind text not null check(kind in('pdf','photo','signature','other')),
 bucket_name text not null default 'voltcore-files', file_path text not null, file_name text not null default '', content_type text not null default '',
 file_size bigint, sha256 text, created_by uuid references auth.users(id) on delete set null, client_updated_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(bucket_name,file_path));

create table if not exists public.project_tasks(
 id uuid primary key default gen_random_uuid(), tenant_id uuid not null references public.tenants(id) on delete cascade,
 task_type public.project_task_type not null, source_id uuid, title text not null, summary text, site_code text not null default '', address text not null default '',
 status public.work_status not null default 'draft', assigned_to_user_id uuid references auth.users(id) on delete set null,
 due_at timestamptz, started_at timestamptz, completed_at timestamptz, archived_at timestamptz,
 created_by uuid references auth.users(id) on delete set null, updated_by uuid references auth.users(id) on delete set null,
 client_updated_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(tenant_id,task_type,source_id));

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_inspections_tenant_date on public.inspections(tenant_id,service_date);
create index if not exists idx_inspections_payload on public.inspections using gin(payload);
create index if not exists idx_maintenance_jobs_tenant_status on public.maintenance_jobs(tenant_id,status);
create index if not exists idx_maintenance_record_data on public.maintenance_records using gin(data);
create index if not exists idx_project_tasks_tenant_status on public.project_tasks(tenant_id,status);
create index if not exists idx_project_tasks_assignee on public.project_tasks(tenant_id,assigned_to_user_id);

-- ---------------------------------------------------------------------------
-- Auth / RLS helper functions
-- ---------------------------------------------------------------------------
create or replace function public.is_tenant_member(tid uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.tenant_members tm where tm.tenant_id=tid and tm.user_id=auth.uid() and tm.is_active)
$$;

create or replace function public.has_tenant_role(p_tenant_id uuid,p_roles public.app_role[]) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.tenant_members where tenant_id=p_tenant_id and user_id=auth.uid() and is_active and role=any(p_roles))
$$;

create or replace function public.can_manage_tenant_work(p_tenant_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select public.has_tenant_role(p_tenant_id,array['admin','supervisor','dispatcher']::public.app_role[])
$$;

create or replace function public.is_assigned_technician(p_tenant_id uuid,p_user_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select p_user_id=auth.uid() and public.has_tenant_role(p_tenant_id,array['technician']::public.app_role[])
$$;

-- These helpers are required by authenticated RLS policies, but are not an
-- anonymous API surface. Trigger-only functions do not need client execution.
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.is_tenant_member(uuid) from public, anon;
revoke all on function public.has_tenant_role(uuid, public.app_role[]) from public, anon;
revoke all on function public.can_manage_tenant_work(uuid) from public, anon;
revoke all on function public.is_assigned_technician(uuid, uuid) from public, anon;
grant execute on function public.is_tenant_member(uuid) to authenticated;
grant execute on function public.has_tenant_role(uuid, public.app_role[]) to authenticated;
grant execute on function public.can_manage_tenant_work(uuid) to authenticated;
grant execute on function public.is_assigned_technician(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS
-- ---------------------------------------------------------------------------
alter table public.tenants                enable row level security;
alter table public.user_profiles          enable row level security;
alter table public.tenant_members         enable row level security;
alter table public.app_settings           enable row level security;
alter table public.sites                  enable row level security;
alter table public.inspections            enable row level security;
alter table public.nameplate_data         enable row level security;
alter table public.test_intervals         enable row level security;
alter table public.maintenance_jobs       enable row level security;
alter table public.maintenance_records    enable row level security;
alter table public.maintenance_parts_used enable row level security;
alter table public.maintenance_attachments enable row level security;
alter table public.project_tasks          enable row level security;

-- ---------------------------------------------------------------------------
-- Policies (idempotent: drop-if-exists then create)
-- Read = any active tenant member. Write = any active tenant member (so field
-- technicians can create/sync offline work). Deletes on the top-level work
-- tables are restricted to managers.
-- ---------------------------------------------------------------------------

drop policy if exists tenants_read on public.tenants;
create policy tenants_read on public.tenants for select using(public.is_tenant_member(id));

drop policy if exists user_profiles_self on public.user_profiles;
create policy user_profiles_self on public.user_profiles for all
  using(user_id=auth.uid()) with check(user_id=auth.uid());

drop policy if exists members_read on public.tenant_members;
create policy members_read on public.tenant_members for select using(public.is_tenant_member(tenant_id));

drop policy if exists app_settings_read on public.app_settings;
create policy app_settings_read on public.app_settings for select using(auth.uid() is not null);

drop policy if exists sites_read on public.sites;
create policy sites_read on public.sites for select using(public.is_tenant_member(tenant_id));
drop policy if exists sites_write on public.sites;
create policy sites_write on public.sites for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

-- Inspections + children
drop policy if exists inspections_read on public.inspections;
create policy inspections_read on public.inspections for select using(public.is_tenant_member(tenant_id));
drop policy if exists inspections_write on public.inspections;
create policy inspections_write on public.inspections for insert with check(public.is_tenant_member(tenant_id));
drop policy if exists inspections_update on public.inspections;
create policy inspections_update on public.inspections for update
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));
drop policy if exists inspections_delete on public.inspections;
create policy inspections_delete on public.inspections for delete using(public.can_manage_tenant_work(tenant_id));

drop policy if exists nameplate_data_all on public.nameplate_data;
create policy nameplate_data_all on public.nameplate_data for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

drop policy if exists test_intervals_all on public.test_intervals;
create policy test_intervals_all on public.test_intervals for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

-- Maintenance + children
drop policy if exists maintenance_jobs_read on public.maintenance_jobs;
create policy maintenance_jobs_read on public.maintenance_jobs for select using(public.is_tenant_member(tenant_id));
drop policy if exists maintenance_jobs_write on public.maintenance_jobs;
create policy maintenance_jobs_write on public.maintenance_jobs for insert with check(public.is_tenant_member(tenant_id));
drop policy if exists maintenance_jobs_update on public.maintenance_jobs;
create policy maintenance_jobs_update on public.maintenance_jobs for update
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));
drop policy if exists maintenance_jobs_delete on public.maintenance_jobs;
create policy maintenance_jobs_delete on public.maintenance_jobs for delete using(public.can_manage_tenant_work(tenant_id));

drop policy if exists maintenance_records_all on public.maintenance_records;
create policy maintenance_records_all on public.maintenance_records for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

drop policy if exists maintenance_parts_all on public.maintenance_parts_used;
create policy maintenance_parts_all on public.maintenance_parts_used for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

drop policy if exists maintenance_attachments_all on public.maintenance_attachments;
create policy maintenance_attachments_all on public.maintenance_attachments for all
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));

-- Project tasks
drop policy if exists project_tasks_read on public.project_tasks;
create policy project_tasks_read on public.project_tasks for select using(public.is_tenant_member(tenant_id));
drop policy if exists project_tasks_write on public.project_tasks;
create policy project_tasks_write on public.project_tasks for insert with check(public.is_tenant_member(tenant_id));
drop policy if exists project_tasks_update on public.project_tasks;
create policy project_tasks_update on public.project_tasks for update
  using(public.is_tenant_member(tenant_id)) with check(public.is_tenant_member(tenant_id));
drop policy if exists project_tasks_delete on public.project_tasks;
create policy project_tasks_delete on public.project_tasks for delete using(public.can_manage_tenant_work(tenant_id));

-- ---------------------------------------------------------------------------
-- Storage buckets + policies
-- ---------------------------------------------------------------------------
insert into storage.buckets(id,name,public) values('voltcore-files','voltcore-files',false)
  on conflict(id) do update set public=false;
insert into storage.buckets(id,name,public) values('maintenance_assets','maintenance_assets',false)
  on conflict(id) do update set public=false;

drop policy if exists voltcore_files_rw on storage.objects;
create policy voltcore_files_rw on storage.objects for all to authenticated
  using(bucket_id in ('voltcore-files','maintenance_assets'))
  with check(bucket_id in ('voltcore-files','maintenance_assets'));

-- ---------------------------------------------------------------------------
-- Auto-provision a user_profiles row on signup
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_auth_user() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 insert into public.user_profiles(user_id,display_name,email)
 values(new.id,coalesce(new.raw_user_meta_data->>'display_name',''),coalesce(new.email,''))
 on conflict(user_id) do nothing;
 return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute function public.handle_new_auth_user();
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;

-- ============================================================================
-- Phase 1 / Phase 2 additions included in a new-project setup
-- ============================================================================
-- These definitions reflect the final state of migrations 0003, 0004, 0006,
-- 20260822205219, and 20260822205311. They intentionally follow the original
-- schema above so this file can also document the project's schema evolution.

-- Remote schedule sync. tenant_id remains text for compatibility with the
-- current Flutter serializer, but the check and RLS policies below require a
-- canonical tenant UUID for every new or changed row.
create table if not exists public.schedule_tasks(
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null default '',
  title text not null default '',
  description text not null default '',
  scheduled_date timestamptz,
  schedule_at timestamptz,
  status text not null default 'scheduled',
  source_type text not null default '',
  source_id text,
  inspection_id text,
  site_code text not null default '',
  site_grade text not null default '',
  address text not null default '',
  assigned_to_user_id text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint schedule_tasks_tenant_id_uuid check (
    tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  )
);

create index if not exists idx_schedule_tasks_date on public.schedule_tasks(scheduled_date);
create index if not exists idx_schedule_tasks_assignee on public.schedule_tasks(assigned_to_user_id);
create index if not exists idx_schedule_tasks_tenant_date
  on public.schedule_tasks(tenant_id, scheduled_date);

alter table public.schedule_tasks enable row level security;
drop policy if exists schedule_tasks_authenticated on public.schedule_tasks;
drop policy if exists schedule_tasks_member_select on public.schedule_tasks;
drop policy if exists schedule_tasks_member_insert on public.schedule_tasks;
drop policy if exists schedule_tasks_member_update on public.schedule_tasks;
drop policy if exists schedule_tasks_member_delete on public.schedule_tasks;
create policy schedule_tasks_member_select on public.schedule_tasks for select to authenticated using (
  case when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_tenant_member(tenant_id::uuid) else false end
);
create policy schedule_tasks_member_insert on public.schedule_tasks for insert to authenticated with check (
  case when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_tenant_member(tenant_id::uuid) else false end
);
create policy schedule_tasks_member_update on public.schedule_tasks for update to authenticated using (
  case when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_tenant_member(tenant_id::uuid) else false end
) with check (
  case when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_tenant_member(tenant_id::uuid) else false end
);
create policy schedule_tasks_member_delete on public.schedule_tasks for delete to authenticated using (
  case when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    then public.is_tenant_member(tenant_id::uuid) else false end
);
revoke all on public.schedule_tasks from anon, authenticated;
grant select, insert, update, delete on public.schedule_tasks to authenticated;

-- Shared, generic asset registry. Generator remains the default asset_type;
-- the metadata field supports non-generator asset-specific attributes.
create table if not exists public.equipment(
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  identity_key text not null,
  name text not null default '',
  make text not null default '',
  model text not null default '',
  serial_number text not null default '',
  voltage text not null default '',
  location text not null default '',
  site_code text not null default '',
  site_grade text not null default '',
  status text not null default 'active',
  last_inspection_at timestamptz,
  inspection_count integer not null default 0,
  latest_inspection_id text,
  is_manual boolean not null default false,
  notes text,
  first_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  asset_type text not null default 'generator',
  metadata jsonb not null default '{}'::jsonb,
  site_id uuid,
  constraint equipment_identity_unique unique(tenant_id, identity_key),
  constraint equipment_status_valid check(status in ('active','inactive','maintenance','retired')),
  constraint equipment_asset_type_not_blank check(length(trim(asset_type)) > 0)
);

create index if not exists idx_equipment_tenant on public.equipment(tenant_id);
create unique index if not exists idx_equipment_tenant_id_id on public.equipment(tenant_id, id);
create index if not exists idx_equipment_serial on public.equipment(tenant_id, serial_number);
create index if not exists idx_equipment_last_inspection
  on public.equipment(tenant_id, last_inspection_at desc nulls last);
create index if not exists idx_equipment_status on public.equipment(tenant_id, status);
create index if not exists idx_equipment_tenant_asset_type on public.equipment(tenant_id, asset_type);
create index if not exists idx_equipment_tenant_site on public.equipment(tenant_id, site_id)
  where site_id is not null;
drop trigger if exists trg_equipment_updated_at on public.equipment;
create trigger trg_equipment_updated_at before update on public.equipment
  for each row execute function public.set_updated_at();

alter table public.equipment enable row level security;
drop policy if exists equipment_read on public.equipment;
drop policy if exists equipment_write on public.equipment;
create policy equipment_read on public.equipment for select to authenticated
  using((select public.is_tenant_member(tenant_id)));
create policy equipment_write on public.equipment for all to authenticated
  using((select public.is_tenant_member(tenant_id)))
  with check((select public.is_tenant_member(tenant_id)));
revoke all on public.equipment from anon, authenticated;
grant select, insert, update, delete on public.equipment to authenticated;

-- Customer directory and optional customer ownership for each service site.
create table if not exists public.customers(
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
  constraint customers_name_not_blank check(length(trim(name)) > 0),
  constraint customers_tenant_name_unique unique(tenant_id, name),
  constraint customers_tenant_id_id_unique unique(tenant_id, id)
);
create index if not exists idx_customers_tenant_active_name
  on public.customers(tenant_id, is_active, name);
drop trigger if exists trg_customers_updated_at on public.customers;
create trigger trg_customers_updated_at before update on public.customers
  for each row execute function public.set_updated_at();

alter table public.sites add column if not exists customer_id uuid;
create unique index if not exists idx_sites_tenant_id_id on public.sites(tenant_id, id);
create index if not exists idx_sites_tenant_customer on public.sites(tenant_id, customer_id)
  where customer_id is not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname='sites_customer_tenant_fk' and conrelid='public.sites'::regclass) then
    alter table public.sites add constraint sites_customer_tenant_fk
      foreign key(tenant_id, customer_id) references public.customers(tenant_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='equipment_tenant_site_fk' and conrelid='public.equipment'::regclass) then
    alter table public.equipment add constraint equipment_tenant_site_fk
      foreign key(tenant_id, site_id) references public.sites(tenant_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='inspections_tenant_site_fk' and conrelid='public.inspections'::regclass) then
    alter table public.inspections add constraint inspections_tenant_site_fk
      foreign key(tenant_id, site_id) references public.sites(tenant_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='maintenance_jobs_tenant_site_fk' and conrelid='public.maintenance_jobs'::regclass) then
    alter table public.maintenance_jobs add constraint maintenance_jobs_tenant_site_fk
      foreign key(tenant_id, site_id) references public.sites(tenant_id, id) on delete restrict;
  end if;
end $$;

alter table public.customers enable row level security;
drop policy if exists customers_read on public.customers;
drop policy if exists customers_manage on public.customers;
drop policy if exists customers_insert on public.customers;
drop policy if exists customers_update on public.customers;
create policy customers_read on public.customers for select to authenticated
  using((select public.is_tenant_member(tenant_id)));
create policy customers_insert on public.customers for insert to authenticated
  with check((select public.can_manage_tenant_work(tenant_id)));
create policy customers_update on public.customers for update to authenticated
  using((select public.can_manage_tenant_work(tenant_id)))
  with check((select public.can_manage_tenant_work(tenant_id)));
revoke all on public.customers from anon, authenticated;
grant select, insert, update on public.customers to authenticated;

drop policy if exists sites_read on public.sites;
drop policy if exists sites_manage on public.sites;
drop policy if exists sites_write on public.sites;
drop policy if exists sites_insert on public.sites;
drop policy if exists sites_update on public.sites;
create policy sites_read on public.sites for select to authenticated
  using((select public.is_tenant_member(tenant_id)));
create policy sites_insert on public.sites for insert to authenticated
  with check((select public.can_manage_tenant_work(tenant_id)));
create policy sites_update on public.sites for update to authenticated
  using((select public.can_manage_tenant_work(tenant_id)))
  with check((select public.can_manage_tenant_work(tenant_id)));
revoke all on public.sites from anon, authenticated;
grant select, insert, update on public.sites to authenticated;

-- Durable field-service work orders. The domain model uses camelCase
-- `inProgress` to match its persisted/offline value, so the database check
-- intentionally retains that exact value.
create table if not exists public.work_orders(
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  title text not null,
  status text not null default 'draft',
  priority text not null default 'normal',
  customer_id uuid,
  site_id uuid,
  asset_id uuid,
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  scheduled_for timestamptz,
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint work_orders_title_not_blank check(length(trim(title)) > 0),
  constraint work_orders_status_valid check(status in ('draft','scheduled','inProgress','completed','cancelled')),
  constraint work_orders_priority_valid check(priority in ('low','normal','high','urgent')),
  constraint work_orders_scheduled_status_check check(status <> 'scheduled' or scheduled_for is not null),
  constraint work_orders_tenant_id_id_unique unique(tenant_id, id)
);

do $$
begin
  if not exists (select 1 from pg_constraint where conname='work_orders_tenant_customer_fk' and conrelid='public.work_orders'::regclass) then
    alter table public.work_orders add constraint work_orders_tenant_customer_fk
      foreign key(tenant_id, customer_id) references public.customers(tenant_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='work_orders_tenant_site_fk' and conrelid='public.work_orders'::regclass) then
    alter table public.work_orders add constraint work_orders_tenant_site_fk
      foreign key(tenant_id, site_id) references public.sites(tenant_id, id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conname='work_orders_tenant_asset_fk' and conrelid='public.work_orders'::regclass) then
    alter table public.work_orders add constraint work_orders_tenant_asset_fk
      foreign key(tenant_id, asset_id) references public.equipment(tenant_id, id) on delete restrict;
  end if;
end $$;

create index if not exists idx_work_orders_tenant_updated on public.work_orders(tenant_id, updated_at desc);
create index if not exists idx_work_orders_tenant_status_schedule
  on public.work_orders(tenant_id, status, scheduled_for)
  where status in ('draft','scheduled','inProgress');
create index if not exists idx_work_orders_tenant_assignee_schedule
  on public.work_orders(tenant_id, assigned_to_user_id, scheduled_for)
  where assigned_to_user_id is not null;
create index if not exists idx_work_orders_tenant_site
  on public.work_orders(tenant_id, site_id) where site_id is not null;
drop trigger if exists trg_work_orders_updated_at on public.work_orders;
create trigger trg_work_orders_updated_at before update on public.work_orders
  for each row execute function public.set_updated_at();

-- This table is append-only from the app's perspective. The trigger below
-- creates creation, lifecycle, and assignee changes at the database boundary.
create table if not exists public.work_order_events(
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  work_order_id uuid not null,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  from_status text,
  to_status text,
  previous_assigned_to_user_id uuid references auth.users(id) on delete set null,
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint work_order_events_type_valid check(event_type in ('created','status_changed','assignment_changed')),
  constraint work_order_events_tenant_work_order_fk
    foreign key(tenant_id, work_order_id) references public.work_orders(tenant_id, id) on delete cascade
);
create index if not exists idx_work_order_events_tenant_work_order_created
  on public.work_order_events(tenant_id, work_order_id, created_at desc);

create or replace function public.record_work_order_event()
returns trigger language plpgsql security definer set search_path=public, pg_temp as $$
begin
  if tg_op = 'INSERT' then
    insert into public.work_order_events(tenant_id, work_order_id, event_type, actor_user_id, to_status, assigned_to_user_id)
      values(new.tenant_id, new.id, 'created', auth.uid(), new.status, new.assigned_to_user_id);
    return new;
  end if;
  if old.status is distinct from new.status then
    insert into public.work_order_events(tenant_id, work_order_id, event_type, actor_user_id, from_status, to_status)
      values(new.tenant_id, new.id, 'status_changed', auth.uid(), old.status, new.status);
  end if;
  if old.assigned_to_user_id is distinct from new.assigned_to_user_id then
    insert into public.work_order_events(tenant_id, work_order_id, event_type, actor_user_id, previous_assigned_to_user_id, assigned_to_user_id)
      values(new.tenant_id, new.id, 'assignment_changed', auth.uid(), old.assigned_to_user_id, new.assigned_to_user_id);
  end if;
  return new;
end;
$$;
drop trigger if exists trg_work_order_event_insert on public.work_orders;
create trigger trg_work_order_event_insert after insert on public.work_orders
  for each row execute function public.record_work_order_event();
drop trigger if exists trg_work_order_event_update on public.work_orders;
create trigger trg_work_order_event_update after update of status, assigned_to_user_id on public.work_orders
  for each row execute function public.record_work_order_event();
revoke all on function public.record_work_order_event() from public, anon, authenticated;

alter table public.work_orders enable row level security;
alter table public.work_order_events enable row level security;
drop policy if exists work_orders_read on public.work_orders;
drop policy if exists work_orders_insert on public.work_orders;
drop policy if exists work_orders_update on public.work_orders;
create policy work_orders_read on public.work_orders for select to authenticated
  using((select public.is_tenant_member(tenant_id)));
create policy work_orders_insert on public.work_orders for insert to authenticated
  with check((select public.is_tenant_member(tenant_id)));
create policy work_orders_update on public.work_orders for update to authenticated
  using((select public.is_tenant_member(tenant_id))) with check((select public.is_tenant_member(tenant_id)));
drop policy if exists work_order_events_read on public.work_order_events;
create policy work_order_events_read on public.work_order_events for select to authenticated
  using((select public.is_tenant_member(tenant_id)));
revoke all on public.work_orders, public.work_order_events from anon, authenticated;
grant select, insert, update on public.work_orders to authenticated;
grant select on public.work_order_events to authenticated;

-- Administration support tables used by the current technician dashboard.
-- These legacy records are not tenant-owned yet; Phase 2's remaining
-- technician-directory work will move them onto tenant_members.
create table if not exists public.technicians(
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Unknown',
  email text,
  phone text,
  role text not null default 'tech',
  is_active boolean not null default true,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_technicians_active on public.technicians(is_active);

create table if not exists public.role_assignments(
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technicians(id) on delete cascade,
  previous_role text not null default '',
  new_role text not null default '',
  assigned_by_user_id uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

alter table public.technicians enable row level security;
alter table public.role_assignments enable row level security;
drop policy if exists technicians_authenticated on public.technicians;
drop policy if exists role_assignments_authenticated on public.role_assignments;
create policy technicians_authenticated on public.technicians for all to authenticated
  using(true) with check(true);
create policy role_assignments_authenticated on public.role_assignments for all to authenticated
  using(true) with check(true);
revoke all on public.technicians, public.role_assignments from anon, authenticated;
grant select, insert, update, delete on public.technicians, public.role_assignments to authenticated;

-- The RPC preserves the mobile client's text parameter while preventing a
-- caller from requesting another user's workload. SECURITY DEFINER is needed
-- to aggregate work rows; the auth.uid() comparison keeps the result scoped to
-- the authenticated technician and tenant-membership checks prevent bypassing
-- row ownership via the function.
create or replace function public.get_tech_dashboard_stats(technician_id text)
returns json
language sql stable security definer set search_path=public, pg_catalog as $$
  select json_build_object(
    'my_open_inspections', (select count(*)::int from public.inspections
      where technician_id = (select auth.uid()::text)
        and assigned_technician_user_id::text = technician_id
        and status not in ('completed','archived','cancelled')
        and public.is_tenant_member(tenant_id)),
    'my_completed_inspections', (select count(*)::int from public.inspections
      where technician_id = (select auth.uid()::text)
        and assigned_technician_user_id::text = technician_id
        and status = 'completed' and public.is_tenant_member(tenant_id)),
    'my_open_maintenance_jobs', (select count(*)::int from public.maintenance_jobs
      where technician_id = (select auth.uid()::text)
        and assigned_technician_user_id::text = technician_id
        and not is_completed and public.is_tenant_member(tenant_id)),
    'my_completed_maintenance_jobs', (select count(*)::int from public.maintenance_jobs
      where technician_id = (select auth.uid()::text)
        and assigned_technician_user_id::text = technician_id
        and is_completed and public.is_tenant_member(tenant_id)),
    'upcoming_tasks', (select count(*)::int from public.schedule_tasks
      where technician_id = (select auth.uid()::text)
        and (assigned_to_user_id = technician_id or assigned_to_user_id is null)
        and scheduled_date >= now() and status in ('scheduled','overdue')
        and tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        and public.is_tenant_member(tenant_id::uuid))
  );
$$;
revoke all on function public.get_tech_dashboard_stats(text) from public, anon;
grant execute on function public.get_tech_dashboard_stats(text) to authenticated;

commit;
+
-- ============================================================================
-- PHASE 3 â VERSIONED TEMPLATE FOUNDATION
-- This section mirrors migrations/20260823190000_phase3_template_foundation.sql.
-- Apply the migration in deployed environments; keep this consolidated file for
-- clean-project setup and schema review.
-- ============================================================================

-- Voltcore FieldOps Phase 3: versioned, tenant-safe form templates.
--
-- A response stores the exact revision used to collect it. Published revisions
-- are append-only at the application boundary; completed responses are also
-- locked in the database so later template edits cannot rewrite field history.

begin;

create table if not exists public.form_templates (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  slug text not null,
  name text not null,
  description text not null default '',
  asset_type text not null default 'generator',
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_templates_slug_not_blank check (length(trim(slug)) > 0),
  constraint form_templates_name_not_blank check (length(trim(name)) > 0),
  constraint form_templates_tenant_slug_unique unique (tenant_id, slug),
  constraint form_templates_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_revisions (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  template_id uuid not null,
  revision_number integer not null,
  status text not null default 'draft',
  title text not null,
  instructions text not null default '',
  settings jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_template_revisions_number_positive check (revision_number > 0),
  constraint form_template_revisions_status_valid
    check (status in ('draft', 'published', 'archived')),
  constraint form_template_revisions_tenant_template_fk
    foreign key (tenant_id, template_id)
    references public.form_templates (tenant_id, id) on delete restrict,
  constraint form_template_revisions_tenant_number_unique
    unique (tenant_id, template_id, revision_number),
  constraint form_template_revisions_tenant_template_id_unique
    unique (tenant_id, template_id, id),
  constraint form_template_revisions_tenant_id_id_unique unique (tenant_id, id)
);

create unique index if not exists idx_form_template_revisions_one_published
  on public.form_template_revisions (tenant_id, template_id)
  where status = 'published';

create table if not exists public.form_template_sections (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  revision_id uuid not null,
  section_key text not null,
  title text not null,
  description text not null default '',
  position integer not null,
  visibility_rule jsonb not null default '{}'::jsonb,

  constraint form_template_sections_key_not_blank check (length(trim(section_key)) > 0),
  constraint form_template_sections_position_nonnegative check (position >= 0),
  constraint form_template_sections_tenant_revision_fk
    foreign key (tenant_id, revision_id)
    references public.form_template_revisions (tenant_id, id) on delete cascade,
  constraint form_template_sections_tenant_revision_key_unique
    unique (tenant_id, revision_id, section_key),
  constraint form_template_sections_tenant_revision_id_unique
    unique (tenant_id, revision_id, id),
  constraint form_template_sections_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_fields (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  revision_id uuid not null,
  section_id uuid not null,
  field_key text not null,
  label text not null,
  help_text text not null default '',
  field_type text not null,
  position integer not null,
  is_required boolean not null default false,
  validation jsonb not null default '{}'::jsonb,
  visibility_rule jsonb not null default '{}'::jsonb,
  default_value jsonb,

  constraint form_template_fields_key_not_blank check (length(trim(field_key)) > 0),
  constraint form_template_fields_label_not_blank check (length(trim(label)) > 0),
  constraint form_template_fields_type_valid check (
    field_type in (
      'text', 'number', 'date', 'select', 'boolean', 'checklist',
      'reading', 'photo', 'signature'
    )
  ),
  constraint form_template_fields_position_nonnegative check (position >= 0),
  constraint form_template_fields_tenant_revision_fk
    foreign key (tenant_id, revision_id)
    references public.form_template_revisions (tenant_id, id) on delete cascade,
  constraint form_template_fields_tenant_section_fk
    foreign key (tenant_id, revision_id, section_id)
    references public.form_template_sections (tenant_id, revision_id, id)
    on delete cascade,
  constraint form_template_fields_tenant_revision_key_unique
    unique (tenant_id, revision_id, field_key),
  constraint form_template_fields_tenant_id_id_unique unique (tenant_id, id)
);

create table if not exists public.form_template_field_options (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  field_id uuid not null,
  option_value text not null,
  label text not null,
  position integer not null,

  constraint form_template_field_options_value_not_blank
    check (length(trim(option_value)) > 0),
  constraint form_template_field_options_label_not_blank
    check (length(trim(label)) > 0),
  constraint form_template_field_options_position_nonnegative check (position >= 0),
  constraint form_template_field_options_tenant_field_fk
    foreign key (tenant_id, field_id)
    references public.form_template_fields (tenant_id, id) on delete cascade,
  constraint form_template_field_options_tenant_field_value_unique
    unique (tenant_id, field_id, option_value)
);

create table if not exists public.form_responses (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  template_id uuid not null,
  template_revision_id uuid not null,
  status text not null default 'draft',
  subject_type text not null default 'asset',
  subject_id uuid,
  customer_id uuid,
  site_id uuid,
  asset_id uuid,
  work_order_id uuid,
  inspection_id uuid,
  maintenance_record_id uuid,
  values jsonb not null default '{}'::jsonb,
  completed_at timestamptz,
  completed_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint form_responses_status_valid check (status in ('draft', 'completed', 'void')),
  constraint form_responses_subject_type_not_blank check (length(trim(subject_type)) > 0),
  constraint form_responses_tenant_template_fk
    foreign key (tenant_id, template_id)
    references public.form_templates (tenant_id, id) on delete restrict,
  constraint form_responses_tenant_revision_fk
    foreign key (tenant_id, template_revision_id)
    references public.form_template_revisions (tenant_id, id) on delete restrict,
  constraint form_responses_tenant_template_revision_fk
    foreign key (tenant_id, template_id, template_revision_id)
    references public.form_template_revisions (tenant_id, template_id, id)
    on delete restrict
);

create index if not exists idx_form_templates_tenant_asset_active
  on public.form_templates (tenant_id, asset_type, is_archived, name);
create index if not exists idx_form_template_revisions_tenant_template_status
  on public.form_template_revisions (tenant_id, template_id, status, revision_number desc);
create index if not exists idx_form_template_sections_tenant_revision_position
  on public.form_template_sections (tenant_id, revision_id, position);
create index if not exists idx_form_template_fields_tenant_revision_position
  on public.form_template_fields (tenant_id, revision_id, section_id, position);
create index if not exists idx_form_template_field_options_tenant_field_position
  on public.form_template_field_options (tenant_id, field_id, position);
create index if not exists idx_form_responses_tenant_revision_updated
  on public.form_responses (tenant_id, template_revision_id, updated_at desc);
create index if not exists idx_form_responses_tenant_asset_updated
  on public.form_responses (tenant_id, asset_id, updated_at desc)
  where asset_id is not null;

drop trigger if exists trg_form_templates_updated_at on public.form_templates;
create trigger trg_form_templates_updated_at
  before update on public.form_templates
  for each row execute function public.set_updated_at();

drop trigger if exists trg_form_template_revisions_updated_at on public.form_template_revisions;
create trigger trg_form_template_revisions_updated_at
  before update on public.form_template_revisions
  for each row execute function public.set_updated_at();

drop trigger if exists trg_form_responses_updated_at on public.form_responses;
create trigger trg_form_responses_updated_at
  before update on public.form_responses
  for each row execute function public.set_updated_at();

create or replace function public.prevent_completed_form_response_edits()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if old.status = 'completed' then
    raise exception 'Completed form responses are immutable.';
  end if;
  return new;
end;
$$;
revoke all on function public.prevent_completed_form_response_edits()
  from public, anon, authenticated;

drop trigger if exists trg_form_responses_lock_completed on public.form_responses;
create trigger trg_form_responses_lock_completed
  before update on public.form_responses
  for each row execute function public.prevent_completed_form_response_edits();

-- Template definitions are controlled by dispatch/supervisory roles. Active
-- tenant members may read published or draft definitions so offline clients
-- can render the revision selected by a work order. Responses are writable by
-- tenant members, but are never client-deletable.
revoke all on public.form_templates, public.form_template_revisions,
  public.form_template_sections, public.form_template_fields,
  public.form_template_field_options, public.form_responses
  from anon, authenticated;
grant select, insert, update on public.form_templates,
  public.form_template_revisions, public.form_template_sections,
  public.form_template_fields, public.form_template_field_options
  to authenticated;
grant select, insert, update on public.form_responses to authenticated;

alter table public.form_templates enable row level security;
alter table public.form_template_revisions enable row level security;
alter table public.form_template_sections enable row level security;
alter table public.form_template_fields enable row level security;
alter table public.form_template_field_options enable row level security;
alter table public.form_responses enable row level security;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'form_templates', 'form_template_revisions', 'form_template_sections',
    'form_template_fields', 'form_template_field_options'
  ] loop
    execute format('drop policy if exists %I on public.%I', table_name || '_read', table_name);
    execute format('drop policy if exists %I on public.%I', table_name || '_manage', table_name);
    execute format(
      'create policy %I on public.%I for select to authenticated using ((select public.is_tenant_member(tenant_id)))',
      table_name || '_read', table_name
    );
    execute format(
      'create policy %I on public.%I for all to authenticated using ((select public.can_manage_tenant_work(tenant_id))) with check ((select public.can_manage_tenant_work(tenant_id)))',
      table_name || '_manage', table_name
    );
  end loop;
end $$;

drop policy if exists form_responses_read on public.form_responses;
drop policy if exists form_responses_insert on public.form_responses;
drop policy if exists form_responses_update on public.form_responses;
create policy form_responses_read on public.form_responses
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));
create policy form_responses_insert on public.form_responses
  for insert to authenticated
  with check ((select public.is_tenant_member(tenant_id)));
create policy form_responses_update on public.form_responses
  for update to authenticated
  using ((select public.is_tenant_member(tenant_id)))
  with check ((select public.is_tenant_member(tenant_id)));

commit;

\n+-- ============================================================================
-- BOOTSTRAP / SEED (run once, fill in the UUIDs)
-- ============================================================================
-- 1) Create the tenant and note its id:
--    insert into public.tenants(name,slug) values('A&S Electric','as-electric') returning id;
--
-- 2) Record it as the active tenant (optional convenience row):
--    insert into public.app_settings(key,value,description)
--    values('active_tenant',jsonb_build_object('tenant_id','<TENANT_UUID>'),'Default Voltcore tenant')
--    on conflict(key) do update set value=excluded.value;
--
-- 3) Add each app user as a tenant member (role: admin/supervisor/dispatcher/technician):
--    insert into public.tenant_members(tenant_id,user_id,role)
--    values('<TENANT_UUID>','<AUTH_USER_UUID>','technician')
--    on conflict(tenant_id,user_id) do update set role=excluded.role, is_active=true;
--
-- 4) Put <TENANT_UUID> in the app: assets/env/.env.* -> SUPABASE_TENANT_ID.
--    The app also needs an authenticated Supabase session (so auth.uid() is set).

-- ============================================================================
-- STRICTER ALTERNATIVE (optional)
-- ============================================================================
-- The write policies above let ANY active tenant member insert/update work
-- rows, which matches the offline field-tech workflow. To restrict creation to
-- managers (and let assigned technicians only edit their own), replace the
-- inspections_write / _update and maintenance_jobs_write / _update policies:
--
--   -- create policy inspections_write on public.inspections for insert
--   --   with check(public.can_manage_tenant_work(tenant_id));
--   -- create policy inspections_update on public.inspections for update
--   --   using(public.can_manage_tenant_work(tenant_id)
--   --         or public.is_assigned_technician(tenant_id,assigned_technician_user_id))
--   --   with check(public.can_manage_tenant_work(tenant_id)
--   --         or public.is_assigned_technician(tenant_id,assigned_technician_user_id));
