-- ---------------------------------------------------------------------------
-- tenant_bootstrap.sql (manual operator runbook; not a database migration)
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
-- inspection returns 403 in the same session. That asymmetry is the diagnosis.
--
-- The app stamps `tenant_id` from SUPABASE_TENANT_ID in assets/env/.env.*.
-- If that value names a tenant that does not exist, or one this user has no
-- membership in, every tenant-scoped insert is rejected. A common symptom is
-- SUPABASE_TENANT_ID being set to the user's own auth uid — the sync log then
-- prints the same uuid for both "User:" and "Tenant:".
--
-- How to use
-- ----------
-- Run STEP 1, then STEP 2, then STEP 3 — one block at a time (select the block
-- and hit run). Replace the email in steps 1 and 2 with the address you sign
-- in with. Everything here is idempotent and safe to re-run.
--
-- NOTE: plain SQL only. `\set` and `:'var'` are psql meta-commands and do not
-- work in the Supabase SQL editor — it strips the backslash and fails with
-- "syntax error at or near". Edit the literal instead.
--
-- IMPORTANT — queued rows do not pick up a new tenant id.
-- The outbox serializes each row at enqueue time, so operations queued before
-- the env change keep the old tenant_id and will keep failing on every retry.
-- After fixing the env, clear the pending queue from the in-app debug menu
-- (or reinstall in development) so the rows are re-serialized.
-- ---------------------------------------------------------------------------


-- ===========================================================================
-- STEP 1 — DIAGNOSE (read-only)
-- ===========================================================================
select
  u.id                                     as user_id,
  (select count(*) from public.tenants)    as tenants_total,
  count(tm.*)                              as memberships_for_user,
  count(tm.*) filter (where tm.is_active)  as active_memberships
from auth.users u
left join public.tenant_members tm on tm.user_id = u.id
where u.email = 'you@example.com'          -- <<< EDIT
group by u.id;

-- Reading the result:
--   no rows returned    -> the email is wrong, or that user never signed up.
--   memberships_for_user = 0 -> run STEP 2.
--   active_memberships  = 0  -> a membership exists but is_active is false;
--                               the app deliberately ignores those. STEP 2
--                               reactivates it.


-- ===========================================================================
-- STEP 2 — FIX. Creates a tenant if none exists, grants this user admin on it.
-- ===========================================================================
do $$
declare
  v_email  text := 'aselectricnyc@gmail.com';      -- <<< EDIT (same address)
  v_user   uuid;
  v_tenant uuid;
begin
  select id into v_user from auth.users where email = v_email;
  if v_user is null then
    raise exception
      'No auth user with email %. Sign up/in once in the app first.', v_email;
  end if;

  -- Reuse the existing tenant when there is exactly one; otherwise create ours.
  -- Bails out rather than guessing if several already exist.
  if (select count(*) from public.tenants) > 1 then
    raise exception
      'More than one tenant exists — pick one by hand and skip this block.';
  end if;

  select id into v_tenant from public.tenants limit 1;

  if v_tenant is null then
    insert into public.tenants (name, slug)
    values ('A&S Electric', 'as-electric')
    returning id into v_tenant;
    raise notice 'Created tenant %', v_tenant;
  end if;

  -- No ON CONFLICT: whether (tenant_id, user_id) carries a unique constraint
  -- varies by install, and a missing constraint would make this fail outright.
  if exists (
    select 1 from public.tenant_members
    where tenant_id = v_tenant and user_id = v_user
  ) then
    update public.tenant_members
       set role = 'admin', is_active = true
     where tenant_id = v_tenant and user_id = v_user;
    raise notice 'Reactivated membership for % on %', v_user, v_tenant;
  else
    insert into public.tenant_members (tenant_id, user_id, role, is_active)
    values (v_tenant, v_user, 'admin', true);
    raise notice 'Granted admin to % on %', v_user, v_tenant;
  end if;
end $$;


-- ===========================================================================
-- STEP 3 — the value to put in SUPABASE_TENANT_ID.
-- Copy `supabase_tenant_id`, paste it into assets/env/.env.*, restart the app.
-- ===========================================================================
select
  t.id    as supabase_tenant_id,
  t.name  as tenant_name,
  u.email as member_email,
  tm.role,
  tm.is_active
from public.tenants t
join public.tenant_members tm on tm.tenant_id = t.id
join auth.users u on u.id = tm.user_id
order by t.name, u.email;


-- ---------------------------------------------------------------------------
-- Optional: re-home rows already written under a wrong tenant id.
-- Only if inspections DID land in Postgres under the bad id and you are the
-- only tenant. Run the select first and look at what you are about to change.
-- ---------------------------------------------------------------------------
-- select tenant_id, count(*) from public.inspections group by tenant_id;
--
-- update public.inspections
--    set tenant_id = '<TENANT_UUID_FROM_STEP_3>'
--  where tenant_id = '<OLD_BAD_UUID>';
