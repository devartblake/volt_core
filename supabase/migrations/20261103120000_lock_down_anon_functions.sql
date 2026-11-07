-- Lock down functions that anonymous callers could reach through the Data API.
--
-- Postgres grants EXECUTE on every new function to PUBLIC, so each
-- SECURITY DEFINER helper in the exposed `public` schema was callable at
-- /rest/v1/rpc/<name> by anyone holding the public key, signed in or not.
-- Supabase's security advisor flagged seven of them (lint 0028).
--
-- Every one of these is a helper for row-level-security or storage policies,
-- which only ever run for signed-in users, so anonymous callers have no
-- legitimate use for them:
--
--   can_access_maintenance_asset, can_update_inspection,
--   can_update_maintenance_job, get_active_tenant_id,
--   storage_job_id, storage_tenant_id          -> policy helpers
--   rls_auto_enable                            -> event-trigger function
--
-- Policy helpers keep EXECUTE for `authenticated` (policies are evaluated with
-- the caller's privileges, so they need it) and `service_role` (Edge
-- Functions). `rls_auto_enable` runs from an event trigger and is not meant to
-- be called by anyone through the API, so it loses `authenticated` as well.
--
-- Not changed: the helpers signed-in users legitimately call
-- (has_tenant_role, is_tenant_member, can_manage_tenant_work,
-- is_assigned_technician, admin_lookup_user_by_email, the template RPCs and
-- get_tech_dashboard_stats). Those check the caller's own identity inside.

revoke execute on function public.can_access_maintenance_asset(text)
  from public, anon;
grant execute on function public.can_access_maintenance_asset(text)
  to authenticated, service_role;

revoke execute on function public.can_update_inspection(uuid)
  from public, anon;
grant execute on function public.can_update_inspection(uuid)
  to authenticated, service_role;

revoke execute on function public.can_update_maintenance_job(uuid)
  from public, anon;
grant execute on function public.can_update_maintenance_job(uuid)
  to authenticated, service_role;

revoke execute on function public.get_active_tenant_id()
  from public, anon;
grant execute on function public.get_active_tenant_id()
  to authenticated, service_role;

revoke execute on function public.storage_job_id(text)
  from public, anon;
grant execute on function public.storage_job_id(text)
  to authenticated, service_role;

revoke execute on function public.storage_tenant_id(text)
  from public, anon;
grant execute on function public.storage_tenant_id(text)
  to authenticated, service_role;

revoke execute on function public.rls_auto_enable()
  from public, anon, authenticated;
