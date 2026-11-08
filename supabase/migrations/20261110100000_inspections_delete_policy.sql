-- Inspections may be deleted by admins and dispatchers only.
--
-- The base schema (supabase/schema/voltcore_complete_schema.sql) allowed
-- delete for can_manage_tenant_work(), which is admin, supervisor AND
-- dispatcher. The app now offers delete to admin and dispatcher only, so the
-- cloud policy is narrowed to match (supervisors and technicians cannot).
-- Read / insert / update policies are unchanged. Idempotent.

begin;

drop policy if exists inspections_delete on public.inspections;
create policy inspections_delete
  on public.inspections
  for delete to authenticated
  using (
    (select public.has_tenant_role(
      tenant_id, array['admin', 'dispatcher']::public.app_role[]))
  );

commit;
