-- ---------------------------------------------------------------------------
-- verify_phase2_tenant_rls.sql (manual operator runbook; not a migration)
--
-- Verifies the Phase 2 customer/site, asset, work-order, and audit-event
-- security contract after migrations are applied. Run each section separately
-- in the Supabase SQL editor. Replace every placeholder UUID before running.
--
-- This uses `set local role authenticated` plus the request JWT subject to
-- exercise the same RLS predicates used by the Data API. All write checks end
-- in ROLLBACK, so they leave no test records behind.
-- ---------------------------------------------------------------------------

-- ==========================================================================
-- STEP 1 — schema, RLS, grants, and trigger contract (read-only)
-- ==========================================================================
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  has_table_privilege('authenticated', c.oid, 'select') as authenticated_can_select,
  has_table_privilege('authenticated', c.oid, 'insert') as authenticated_can_insert,
  has_table_privilege('authenticated', c.oid, 'update') as authenticated_can_update,
  has_table_privilege('authenticated', c.oid, 'delete') as authenticated_can_delete
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('customers', 'sites', 'equipment', 'work_orders', 'work_order_events')
order by c.relname;

-- Expected:
-- * RLS is enabled on every listed table.
-- * authenticated has no DELETE permission for Phase 2 records.
-- * authenticated has SELECT only (not INSERT/UPDATE) for work_order_events.

select
  t.tgname as trigger_name,
  p.proname as function_name,
  has_function_privilege('authenticated', p.oid, 'execute') as authenticated_can_execute
from pg_trigger t
join pg_proc p on p.oid = t.tgfoid
where t.tgrelid = 'public.work_orders'::regclass
  and not t.tgisinternal
order by t.tgname;

-- Expected: both work-order event triggers exist and authenticated cannot call
-- record_work_order_event directly.


-- ==========================================================================
-- STEP 2 — member can create a work order and read its trigger-owned event
-- ==========================================================================
-- Replace these values with an active user's UUID and one tenant that user
-- belongs to. The ROLLBACK makes this safe for staging and production.
begin;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '<MEMBER_USER_UUID>', true);

with created as (
  insert into public.work_orders (
    id, tenant_id, title, status, priority, description
  ) values (
    gen_random_uuid(), '<MEMBER_TENANT_UUID>', 'RLS verification — rollback',
    'draft', 'normal', 'Temporary Phase 2 RLS verification row'
  )
  returning id, tenant_id
)
select
  created.id as work_order_id,
  count(events.*) as generated_events
from created
left join public.work_order_events events
  on events.tenant_id = created.tenant_id
 and events.work_order_id = created.id
group by created.id;

-- Expected: exactly one generated_events row (the database-owned "created"
-- audit event). Do not COMMIT this verification row.
rollback;


-- ==========================================================================
-- STEP 3 — cross-tenant rows are invisible to the member (read-only)
-- ==========================================================================
-- Use a second tenant UUID the member does NOT belong to. This query should
-- return 0, even if an administrator can confirm that tenant has records.
begin;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '<MEMBER_USER_UUID>', true);

select count(*) as cross_tenant_work_orders_visible
from public.work_orders
where tenant_id = '<OTHER_TENANT_UUID>';
rollback;


-- ==========================================================================
-- STEP 4 — direct audit writes are disallowed (read-only grant check)
-- ==========================================================================
-- Expected: f / false. The activity timeline must be populated only by
-- work_orders triggers, never by Flutter client inserts.
select has_table_privilege(
  'authenticated', 'public.work_order_events', 'insert'
) as direct_audit_insert_allowed;
