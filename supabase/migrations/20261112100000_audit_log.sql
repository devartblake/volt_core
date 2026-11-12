-- Audit log: who changed or deleted what, for the records that matter.
--
--   * public.audit_log        append-only; admins of the company can read it,
--                             nobody can write it except the trigger function
--   * public.log_row_change() generic AFTER ROW trigger function (SECURITY
--                             DEFINER). Records action, table, record id,
--                             tenant, and old/new JSON. UPDATE keeps only the
--                             top-level keys that changed, and skips updates
--                             where only updated_at / updated_by changed.
--                             Values over ~4 KB (payload, data, changes...)
--                             are replaced by the text '[omitted]'.
--   * public.purge_audit_log(p_days)  retention, for admins or a cron job.
--                             Documented, NOT scheduled.
--
-- Audited: inspections (update, delete), maintenance_jobs (delete),
-- part_prices, vendors (all), purchase_orders (update, delete),
-- inventory_movements (insert of adjust / count only), inventory_locations
-- (all), tenant_members (all), user_profiles (update of is_active / email),
-- profile_change_requests (status change), vehicle_inspections (delete).
--
-- Idempotent. A failure to write an audit row never blocks the change itself
-- (it is raised as a WARNING).

begin;

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  tenant_id uuid,
  table_name text not null,
  record_id text,
  action text not null,
  actor_user_id uuid default auth.uid(),
  changed_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb,
  summary text,
  constraint audit_log_action_valid
    check (action in ('insert', 'update', 'delete'))
);

create index if not exists idx_audit_log_tenant_time
  on public.audit_log (tenant_id, changed_at desc);
create index if not exists idx_audit_log_table_record
  on public.audit_log (table_name, record_id);

alter table public.audit_log enable row level security;

revoke all on public.audit_log from public;
revoke all on public.audit_log from anon;
revoke insert, update, delete, truncate on public.audit_log from authenticated;
grant select on public.audit_log to authenticated;

-- Admins of the company read; there is deliberately no insert / update /
-- delete policy.
drop policy if exists audit_log_admin_read on public.audit_log;
create policy audit_log_admin_read on public.audit_log
  for select to authenticated
  using (
    tenant_id is not null
    and public.has_tenant_role(tenant_id, array['admin']::public.app_role[])
  );

-- ---------------------------------------------------------------------------
-- 2. Append-only guard
-- ---------------------------------------------------------------------------
create or replace function public.audit_log_block_mutation()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  -- purge_audit_log() sets this for its own transaction only.
  if tg_op = 'DELETE'
     and coalesce(current_setting('voltcore.audit_purge', true), '') = 'on' then
    return old;
  end if;
  raise exception 'audit_log is append-only (% refused)', tg_op
    using errcode = 'insufficient_privilege';
end;
$$;

drop trigger if exists trg_audit_log_no_update on public.audit_log;
create trigger trg_audit_log_no_update
  before update on public.audit_log
  for each row execute function public.audit_log_block_mutation();

drop trigger if exists trg_audit_log_no_delete on public.audit_log;
create trigger trg_audit_log_no_delete
  before delete on public.audit_log
  for each row execute function public.audit_log_block_mutation();

-- ---------------------------------------------------------------------------
-- 3. Helper: replace any top-level value over ~4 KB with '[omitted]'
-- ---------------------------------------------------------------------------
create or replace function public.audit_strip_bulky(p_row jsonb)
returns jsonb
language sql
immutable
set search_path = public, pg_temp
as $$
  select case
    when p_row is null then null
    else coalesce(
      (select jsonb_object_agg(
                e.key,
                case
                  when length(e.value::text) > 4096
                    then to_jsonb('[omitted]'::text)
                  else e.value
                end)
         from jsonb_each(p_row) e),
      '{}'::jsonb)
  end;
$$;

-- ---------------------------------------------------------------------------
-- 4. The generic trigger function
-- ---------------------------------------------------------------------------
create or replace function public.log_row_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_action text := lower(tg_op);
  v_verb text;
  v_table text := tg_table_name;
  v_tenant uuid;
  v_record text;
  v_label text;
  v_summary text;
  v_changed text[];
  v_old_diff jsonb;
  v_new_diff jsonb;
  -- Keys that never count as a change on their own.
  v_noise text[] := array['updated_at', 'updated_by'];
  -- If set, only these keys are considered.
  v_only text[];
begin
  if tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_row := v_old;
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_row := v_new;
  else
    v_new := to_jsonb(new);
    v_row := v_new;
  end if;

  v_verb := case v_action
    when 'insert' then 'Added'
    when 'update' then 'Updated'
    else 'Deleted'
  end;

  -- Per-table rules.
  if v_table = 'inspections' then
    -- The synced form body changes on every save; the interesting changes are
    -- the identity columns.
    v_noise := v_noise || array['payload', 'client_updated_at'];
  elsif v_table = 'user_profiles' then
    v_only := array['is_active', 'email'];
  end if;

  -- Record id: the row id, or the table's key.
  if v_table = 'tenant_members' then
    v_record := (v_row ->> 'tenant_id') || ':' || (v_row ->> 'user_id');
  else
    v_record := coalesce(v_row ->> 'id', v_row ->> 'user_id');
  end if;

  -- Company.
  v_tenant := nullif(v_row ->> 'tenant_id', '')::uuid;
  if v_tenant is null and v_table = 'user_profiles' then
    select tm.tenant_id into v_tenant
      from public.tenant_members tm
     where tm.user_id = (v_row ->> 'user_id')::uuid
     order by tm.is_active desc, tm.created_at
     limit 1;
  end if;

  -- UPDATE: keep only the keys that changed.
  if tg_op = 'UPDATE' then
    select coalesce(array_agg(k.key order by k.key), array[]::text[])
      into v_changed
      from jsonb_each(v_new) k
     where (v_only is null or k.key = any(v_only))
       and not (k.key = any(v_noise))
       and (v_old -> k.key) is distinct from k.value;

    if coalesce(array_length(v_changed, 1), 0) = 0 then
      return null; -- nothing worth recording
    end if;

    select jsonb_object_agg(x.key, x.value) into v_old_diff
      from jsonb_each(v_old) x where x.key = any(v_changed);
    select jsonb_object_agg(x.key, x.value) into v_new_diff
      from jsonb_each(v_new) x where x.key = any(v_changed);
    v_old := v_old_diff;
    v_new := v_new_diff;
  end if;

  -- A short human label for the record.
  v_label := case v_table
    when 'inspections' then
      coalesce(nullif(v_row ->> 'site_code', ''),
               nullif(v_row ->> 'address', ''), v_record)
    when 'maintenance_jobs' then
      coalesce(nullif(v_row ->> 'title', ''),
               nullif(v_row ->> 'site_code', ''), v_record)
    when 'vendors' then coalesce(nullif(v_row ->> 'name', ''), v_record)
    when 'purchase_orders' then
      coalesce(nullif(v_row ->> 'po_number', ''), v_record)
    when 'inventory_locations' then
      coalesce(nullif(v_row ->> 'name', ''), v_record)
    when 'user_profiles' then
      coalesce(nullif(v_row ->> 'display_name', ''),
               nullif(v_row ->> 'email', ''), v_record)
    when 'tenant_members' then
      coalesce(
        (select nullif(up.display_name, '')
           from public.user_profiles up
          where up.user_id = (v_row ->> 'user_id')::uuid),
        v_row ->> 'user_id')
    when 'profile_change_requests' then
      coalesce(nullif(v_row ->> 'equipment_key', ''), v_record)
    else v_record
  end;

  v_summary := case v_table
    when 'inspections' then v_verb || ' inspection ' || v_label
    when 'maintenance_jobs' then v_verb || ' maintenance job ' || v_label
    when 'part_prices' then v_verb || ' a part price'
    when 'vendors' then v_verb || ' vendor ' || v_label
    when 'purchase_orders' then v_verb || ' purchase order ' || v_label
    when 'inventory_movements' then
      'Stock ' || coalesce(v_row ->> 'reason', 'change') || ' of '
        || coalesce(v_row ->> 'qty_delta', '?')
    when 'inventory_locations' then v_verb || ' location ' || v_label
    when 'tenant_members' then
      case v_action
        when 'insert' then 'Added team member ' || v_label
        when 'delete' then 'Removed team member ' || v_label
        else 'Changed team member ' || v_label
      end
    when 'user_profiles' then 'Changed account ' || v_label
    when 'profile_change_requests' then
      'Parts profile request ' || coalesce(v_row ->> 'status', 'changed')
        || ' for ' || v_label
    when 'vehicle_inspections' then 'Deleted vehicle inspection ' || v_record
    else v_verb || ' ' || v_table || ' ' || v_record
  end;

  begin
    insert into public.audit_log (
      tenant_id, table_name, record_id, action, actor_user_id,
      old_data, new_data, summary
    ) values (
      v_tenant, v_table, v_record, v_action, auth.uid(),
      public.audit_strip_bulky(v_old), public.audit_strip_bulky(v_new),
      left(v_summary, 500)
    );
  exception when others then
    raise warning 'audit_log write failed for %: %', v_table, sqlerrm;
  end;

  return null;
end;
$$;

revoke all on function public.log_row_change() from public, anon, authenticated;
revoke all on function public.audit_strip_bulky(jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. Triggers (AFTER, per row)
-- ---------------------------------------------------------------------------
drop trigger if exists trg_audit_inspections on public.inspections;
create trigger trg_audit_inspections
  after update or delete on public.inspections
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_maintenance_jobs on public.maintenance_jobs;
create trigger trg_audit_maintenance_jobs
  after delete on public.maintenance_jobs
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_part_prices on public.part_prices;
create trigger trg_audit_part_prices
  after insert or update or delete on public.part_prices
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_vendors on public.vendors;
create trigger trg_audit_vendors
  after insert or update or delete on public.vendors
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_purchase_orders on public.purchase_orders;
create trigger trg_audit_purchase_orders
  after update or delete on public.purchase_orders
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_inventory_movements
  on public.inventory_movements;
create trigger trg_audit_inventory_movements
  after insert on public.inventory_movements
  for each row
  when (new.reason in ('adjust', 'count'))
  execute function public.log_row_change();

drop trigger if exists trg_audit_inventory_locations
  on public.inventory_locations;
create trigger trg_audit_inventory_locations
  after insert or update or delete on public.inventory_locations
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_tenant_members on public.tenant_members;
create trigger trg_audit_tenant_members
  after insert or update or delete on public.tenant_members
  for each row execute function public.log_row_change();

drop trigger if exists trg_audit_user_profiles on public.user_profiles;
create trigger trg_audit_user_profiles
  after update of is_active, email on public.user_profiles
  for each row
  when (old.is_active is distinct from new.is_active
        or old.email is distinct from new.email)
  execute function public.log_row_change();

drop trigger if exists trg_audit_profile_change_requests
  on public.profile_change_requests;
create trigger trg_audit_profile_change_requests
  after update of status on public.profile_change_requests
  for each row
  when (old.status is distinct from new.status)
  execute function public.log_row_change();

drop trigger if exists trg_audit_vehicle_inspections
  on public.vehicle_inspections;
create trigger trg_audit_vehicle_inspections
  after delete on public.vehicle_inspections
  for each row execute function public.log_row_change();

-- ---------------------------------------------------------------------------
-- 6. Retention
-- ---------------------------------------------------------------------------
-- Deletes audit rows older than p_days (default two years; at least 30).
-- Called by an admin it purges their own company's rows; called without a
-- signed-in user (cron, service role) it purges every company. Returns the
-- number of rows removed. NOT scheduled; to run it monthly with pg_cron:
--   select cron.schedule('purge-audit-log', '0 3 1 * *',
--     $$select public.purge_audit_log(730)$$);
create or replace function public.purge_audit_log(p_days int default 730)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_days int := greatest(coalesce(p_days, 730), 30);
  v_count bigint;
begin
  if v_uid is not null and not exists (
    select 1 from public.tenant_members tm
     where tm.user_id = v_uid and tm.is_active and tm.role = 'admin'
  ) then
    raise exception 'Only an admin can purge the audit log.'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('voltcore.audit_purge', 'on', true);

  with gone as (
    delete from public.audit_log a
     where a.changed_at < now() - make_interval(days => v_days)
       and (
         v_uid is null
         or a.tenant_id in (
           select tm.tenant_id from public.tenant_members tm
            where tm.user_id = v_uid and tm.is_active and tm.role = 'admin')
       )
    returning 1
  )
  select count(*) into v_count from gone;

  perform set_config('voltcore.audit_purge', 'off', true);
  return v_count;
end;
$$;

revoke all on function public.purge_audit_log(int) from public, anon;
grant execute on function public.purge_audit_log(int)
  to authenticated, service_role;

commit;
