-- Voltcore FieldOps Phase 1: tenant-safe scheduling and generic assets.
--
-- Prerequisite: every active user and every new schedule write must have a
-- tenant created through supabase/manual/tenant_bootstrap.sql. Legacy schedule rows whose
-- tenant cannot be verified are deliberately retained but inaccessible until
-- an administrator explicitly re-homes them.

begin;

-- ---------------------------------------------------------------------------
-- 1. Scheduling: block cross-tenant access without guessing legacy ownership.
-- ---------------------------------------------------------------------------

-- New/updated rows must carry a canonical UUID. NOT VALID preserves historic
-- blank values so this migration is non-destructive; PostgreSQL still enforces
-- the constraint for all subsequent INSERTs and UPDATEs.
alter table public.schedule_tasks
  add constraint schedule_tasks_tenant_id_uuid
  check (
    tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ) not valid;

create index if not exists idx_schedule_tasks_tenant_date
  on public.schedule_tasks (tenant_id, scheduled_date);

drop policy if exists schedule_tasks_authenticated on public.schedule_tasks;
drop policy if exists schedule_tasks_member_select on public.schedule_tasks;
drop policy if exists schedule_tasks_member_insert on public.schedule_tasks;
drop policy if exists schedule_tasks_member_update on public.schedule_tasks;
drop policy if exists schedule_tasks_member_delete on public.schedule_tasks;

-- CASE prevents an invalid legacy text value from being cast to uuid. It also
-- makes a tenantless legacy row invisible instead of exposing it to every
-- authenticated user.
create policy schedule_tasks_member_select on public.schedule_tasks
  for select to authenticated
  using (
    case
      when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_tenant_member(tenant_id::uuid)
      else false
    end
  );

create policy schedule_tasks_member_insert on public.schedule_tasks
  for insert to authenticated
  with check (
    case
      when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_tenant_member(tenant_id::uuid)
      else false
    end
  );

create policy schedule_tasks_member_update on public.schedule_tasks
  for update to authenticated
  using (
    case
      when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_tenant_member(tenant_id::uuid)
      else false
    end
  )
  with check (
    case
      when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_tenant_member(tenant_id::uuid)
      else false
    end
  );

create policy schedule_tasks_member_delete on public.schedule_tasks
  for delete to authenticated
  using (
    case
      when tenant_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then public.is_tenant_member(tenant_id::uuid)
      else false
    end
  );

-- Explicit grants are required by newer Supabase projects that have opted out
-- of automatic Data API exposure for public-schema tables.
grant select, insert, update, delete on public.schedule_tasks to authenticated;

-- Re-home only after confirming the row belongs to the target tenant. The
-- precise id condition is intentional: never bulk-assign unknown history.
-- update public.schedule_tasks
--    set tenant_id = '<TENANT_UUID>'
--  where id = '<LEGACY_SCHEDULE_TASK_UUID>'
--    and tenant_id = '<PREVIOUS_TENANT_UUID_OR_BLANK>';

-- ---------------------------------------------------------------------------
-- 2. Asset vocabulary: existing equipment remains compatible and becomes the
--    shared registry for all field-service asset types.
-- ---------------------------------------------------------------------------

alter table public.equipment
  add column if not exists asset_type text not null default 'generator',
  add column if not exists metadata jsonb not null default '{}'::jsonb,
  add column if not exists site_id uuid references public.sites(id) on delete set null;

alter table public.equipment
  drop constraint if exists equipment_asset_type_not_blank;
alter table public.equipment
  add constraint equipment_asset_type_not_blank
  check (length(trim(asset_type)) > 0);

create index if not exists idx_equipment_tenant_asset_type
  on public.equipment (tenant_id, asset_type);
create index if not exists idx_equipment_tenant_site
  on public.equipment (tenant_id, site_id)
  where site_id is not null;

grant select, insert, update, delete on public.equipment to authenticated;

commit;
