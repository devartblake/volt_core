-- Voltcore migration 0003: tables/RPC the app queries but no schema created
--
-- The app actively references these and errors without them:
--   * schedule_tasks            (Schedule page remote sync)
--   * technicians               (Admin dashboard: list, role editing, stats)
--   * role_assignments          (Admin role-change audit trail)
--   * get_tech_dashboard_stats  (RPC for the technician dashboard)
--
-- Column names/types match the app's serializers EXACTLY:
--   * schedule_tasks  -> ScheduleTaskModel.toJson  (note: key is `schedule_at`,
--     not `scheduled_at`, and the app currently sends tenant_id/source_id as
--     plain strings — sometimes empty — so those columns are TEXT, not uuid,
--     to avoid 22P02 "invalid input syntax for type uuid" errors)
--   * technicians     -> TechnicianModel.fromMap/toMap
--   * role_assignments-> AdminRemoteDatasource.insertRoleAssignment
--   * RPC result      -> DashboardStatsModel.fromMap keys
--
-- Idempotent; run in the Supabase SQL editor after the complete schema. RLS is
-- authenticated-scoped (these tables aren't part of the tenant design yet —
-- see the note at the end).

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- schedule_tasks
-- ---------------------------------------------------------------------------
create table if not exists public.schedule_tasks(
  id uuid primary key default gen_random_uuid(),
  tenant_id text not null default '',
  title text not null default '',
  description text not null default '',
  scheduled_date timestamptz,
  schedule_at timestamptz,             -- app key is literally `schedule_at`
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
  updated_at timestamptz not null default now()
);

create index if not exists idx_schedule_tasks_date on public.schedule_tasks(scheduled_date);
create index if not exists idx_schedule_tasks_assignee on public.schedule_tasks(assigned_to_user_id);

-- ---------------------------------------------------------------------------
-- technicians
-- ---------------------------------------------------------------------------
create table if not exists public.technicians(
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Unknown',
  email text,
  phone text,
  role text not null default 'tech',   -- tech | supervisor | dispatcher | admin
  is_active boolean not null default true,
  last_activity_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_technicians_active on public.technicians(is_active);

-- ---------------------------------------------------------------------------
-- role_assignments (audit trail for role changes)
-- ---------------------------------------------------------------------------
create table if not exists public.role_assignments(
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.technicians(id) on delete cascade,
  previous_role text not null default '',
  new_role text not null default '',
  assigned_by_user_id uuid references auth.users(id) on delete set null,
  reason text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- RPC: get_tech_dashboard_stats
-- Param is TEXT (the app passes a string id); returns the exact JSON keys
-- DashboardStatsModel.fromMap expects.
-- ---------------------------------------------------------------------------
create or replace function public.get_tech_dashboard_stats(technician_id text)
returns json
language sql stable security definer set search_path=public as $$
  select json_build_object(
    'my_open_inspections', (
      select count(*)::int from public.inspections
      where assigned_technician_user_id::text = technician_id
        and status not in ('completed','archived','cancelled')
    ),
    'my_completed_inspections', (
      select count(*)::int from public.inspections
      where assigned_technician_user_id::text = technician_id
        and status = 'completed'
    ),
    'my_open_maintenance_jobs', (
      select count(*)::int from public.maintenance_jobs
      where assigned_technician_user_id::text = technician_id
        and not is_completed
    ),
    'my_completed_maintenance_jobs', (
      select count(*)::int from public.maintenance_jobs
      where assigned_technician_user_id::text = technician_id
        and is_completed
    ),
    'upcoming_tasks', (
      select count(*)::int from public.schedule_tasks
      where (assigned_to_user_id = technician_id or assigned_to_user_id is null)
        and scheduled_date >= now()
        and status in ('scheduled','overdue')
    )
  );
$$;

-- ---------------------------------------------------------------------------
-- RLS: authenticated users only. These tables aren't tenant-scoped yet (the
-- app sends tenant_id as a plain, often-empty string), so tenant policies
-- can't apply — gate on a signed-in session instead.
-- ---------------------------------------------------------------------------
alter table public.schedule_tasks   enable row level security;
alter table public.technicians      enable row level security;
alter table public.role_assignments enable row level security;

drop policy if exists schedule_tasks_authenticated on public.schedule_tasks;
create policy schedule_tasks_authenticated on public.schedule_tasks
  for all to authenticated using (true) with check (true);

drop policy if exists technicians_authenticated on public.technicians;
create policy technicians_authenticated on public.technicians
  for all to authenticated using (true) with check (true);

drop policy if exists role_assignments_authenticated on public.role_assignments;
create policy role_assignments_authenticated on public.role_assignments
  for all to authenticated using (true) with check (true);

commit;

-- ---------------------------------------------------------------------------
-- REMINDER — required bootstrap for the main sync tables (from earlier setup):
--   insert into public.tenants(name,slug) values('A&S Electric','as-electric') returning id;
--   insert into public.tenant_members(tenant_id,user_id,role)
--     values('<TENANT_UUID>','<AUTH_USER_UUID>','admin');
--   -- then set SUPABASE_TENANT_ID="<TENANT_UUID>" in assets/env/.env.*
--
-- Seed technicians so the Admin dashboard has data, e.g.:
--   insert into public.technicians(name,email,role) values
--     ('Alex Rivera','alex@example.com','tech');
--
-- FUTURE CLEANUP: fold technicians/role_assignments into the
-- user_profiles + tenant_members design, and make schedule_tasks tenant-scoped
-- (uuid tenant_id + is_tenant_member policies) once the app stamps real
-- tenant ids on scheduled tasks.
