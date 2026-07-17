-- ============================================================================
-- Voltcore / A&S Electric — COMPLETE Supabase schema (app-aligned)
-- ============================================================================
-- Single, self-contained, idempotent setup for the projects database. Safe to
-- run once or re-run. It is a superset of the consolidated v2 schema, aligned
-- with what the Flutter app actually reads/writes:
--
--   * inspections           -> identity columns + `payload` jsonb
--   * maintenance_jobs       -> identity row (id == app record id)
--   * maintenance_records    -> `data` jsonb, job_id == app record id
--   * files (pdf/signature/photo) -> Storage bucket 'voltcore-files'
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
-- If your ChatGPT design session defined extra tables/columns, share them and
-- they can be merged — this file is built from the v2 schema + the app code.
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

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at=now(); return new; end $$;

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

commit;

-- ============================================================================
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
