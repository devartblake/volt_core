-- ---------------------------------------------------------------------------
-- 0005_tenant_bootstrap.sql
--
-- Fixes: POST /rest/v1/inspections -> 403
--   "new row violates row-level security policy for table \"inspections\"" (42501)
--
-- Why it happens
-- --------------
-- `inspections` (and `maintenance_records`, `equipment`) are tenant-scoped:
-- their policies call `public.is_tenant_member(tenant_id)`, which is true only
-- when an *active* `tenant_members` row pairs the signed-in user with that
-- tenant. `schedule_tasks` is NOT tenant-scoped — migration 0003 gates it on
-- `authenticated` alone — which is why scheduling returns 201 while saving an
-- inspection returns 403 in the same session. The asymmetry is the tell.
--
-- The app stamps `tenant_id` from SUPABASE_TENANT_ID in assets/env/.env.*.
-- If that value names a tenant that does not exist, or one this user has no
-- membership in, every tenant-scoped insert is rejected. A common symptom is
-- SUPABASE_TENANT_ID being set to the user's own auth uid — the sync log then
-- prints the same uuid for both "User:" and "Tenant:".
--
-- How to use
-- ----------
-- 1. Set :app_email below to the address you sign in with.
-- 2. Run the DIAGNOSE block. It tells you which of the three things is missing.
-- 3. Run the FIX block. It is idempotent — safe to re-run.
-- 4. Copy the tenant id it prints into SUPABASE_TENANT_ID in your env file,
--    then restart the app (dotenv is read once at startup).
--
-- IMPORTANT — queued rows do not pick up a new tenant id.
-- The outbox serializes each row at enqueue time, so operations queued before
-- the env change keep the old tenant_id and will keep failing on every retry.
-- After fixing the env, clear the pending queue from the in-app debug menu
-- (or reinstall in development) so the rows are re-serialized.
-- ---------------------------------------------------------------------------

\set app_email 'you@example.com'

-- ---------------------------------------------------------------------------
-- DIAGNOSE — read-only. Run this first.
-- ---------------------------------------------------------------------------
with u as (
  select id, email from auth.users where email = :'app_email'
)
select
  (select id from u)                                  as user_id,
  (select count(*) from u)                            as user_found,
  (select count(*) from public.tenants)               as tenants_total,
  (select count(*)
     from public.tenant_members tm
     join u on u.id = tm.user_id)                     as memberships_for_user,
  (select count(*)
     from public.tenant_members tm
     join u on u.id = tm.user_id
    where tm.is_active)                               as active_memberships;

-- Reading the result:
--   user_found = 0          -> the email is wrong, or the user never signed up.
--   memberships_for_user = 0 -> run the FIX block below.
--   active_memberships = 0   -> a membership exists but is_active is false;
--                               the app deliberately ignores those.

-- ---------------------------------------------------------------------------
-- FIX — creates a tenant if none exists and grants this user admin on it.
-- Idempotent.
-- ---------------------------------------------------------------------------
begin;

-- Reuse the existing tenant when there is exactly one; otherwise create ours.
insert into public.tenants (name, slug)
select 'A&S Electric', 'as-electric'
where not exists (select 1 from public.tenants);

with u as (
  select id from auth.users where email = :'app_email'
),
t as (
  select id from public.tenants order by created_at limit 1
)
insert into public.tenant_members (tenant_id, user_id, role, is_active)
select t.id, u.id, 'admin', true
from t, u
on conflict (tenant_id, user_id) do update
  set role = 'admin',
      is_active = true;

commit;

-- ---------------------------------------------------------------------------
-- The value to put in SUPABASE_TENANT_ID.
-- ---------------------------------------------------------------------------
select
  t.id     as supabase_tenant_id,
  t.name   as tenant_name,
  tm.role,
  tm.is_active
from public.tenants t
join public.tenant_members tm on tm.tenant_id = t.id
join auth.users u on u.id = tm.user_id
where u.email = :'app_email';

-- ---------------------------------------------------------------------------
-- Optional: re-home rows already written under a wrong tenant id.
-- Only run this if inspections did land in Postgres under the bad id AND you
-- are the only tenant. Check the SELECT before running the UPDATE.
-- ---------------------------------------------------------------------------
-- select tenant_id, count(*) from public.inspections group by tenant_id;
--
-- update public.inspections
--    set tenant_id = '<TENANT_UUID_FROM_ABOVE>'
--  where tenant_id = '<OLD_BAD_UUID>';
