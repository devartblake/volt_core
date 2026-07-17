-- Voltcore: Supabase setup for the app's (jsonb-aligned) sync
--
-- The app now writes rows that MATCH the consolidated v2 schema:
--   * public.inspections      -> identity columns + `payload` jsonb
--   * public.maintenance_jobs -> identity row (one per record id)
--   * public.maintenance_records -> `data` jsonb, job_id = record id
-- so no flat business columns need to be added. If you previously ran the
-- flat-column version of this file, those extra columns are harmless (unused).
--
-- The v2 schema already creates the tables, RLS, and helper functions. This
-- migration only adds what the v2 file did not: the storage bucket the app
-- uploads to. Run it in the Supabase SQL editor. Safe to re-run.

begin;

-- Storage bucket for PDF / signature / photo backups. The app uploads to the
-- bucket named by SUPABASE_STORAGE_BUCKET (default 'voltcore-files'); the base
-- schema only created 'maintenance_assets'.
insert into storage.buckets(id, name, public)
values ('voltcore-files', 'voltcore-files', false)
on conflict (id) do nothing;

commit;

-- ============================================================================
-- REQUIRED APP CONFIG
-- ============================================================================
-- Every synced row is stamped with tenant_id (multi-tenant RLS). Set the app's
-- SUPABASE_TENANT_ID env var to a real tenant UUID, created by the v2 bootstrap:
--
--   insert into public.tenants(name,slug) values('A&S Electric','as-electric')
--     returning id;   -- put this UUID in assets/env/.env.* as SUPABASE_TENANT_ID
--
-- Then make the technician a member so RLS lets them write:
--   insert into public.tenant_members(tenant_id,user_id,role)
--   values('<TENANT_UUID>','<AUTH_USER_UUID>','technician');  -- or admin/supervisor

-- ============================================================================
-- RLS / AUTH (decide before production)
-- ============================================================================
-- RLS write policies require can_manage_tenant_work(tenant_id) or
-- is_assigned_technician(...). For those to pass, the app must:
--   1) authenticate the user via Supabase Auth (so auth.uid() is set), and
--   2) stamp rows with a tenant_id the user is a member of (SUPABASE_TENANT_ID).
-- With both in place the existing v2 policies work as-is — no changes needed.
--
-- Note: the v2 policies cover inspections / maintenance_jobs / project_tasks but
-- NOT maintenance_records (detail). Add read/write policies for it, e.g.:
--
--   -- create policy maintenance_records_read on public.maintenance_records
--   --   for select using (public.is_tenant_member(tenant_id));
--   -- create policy maintenance_records_write on public.maintenance_records
--   --   for all using (public.can_manage_tenant_work(tenant_id))
--   --   with check (public.can_manage_tenant_work(tenant_id));

-- ============================================================================
-- STORAGE POLICIES
-- ============================================================================
-- Uploads to 'voltcore-files' need storage.objects RLS policies allowing the
-- authenticated user to insert/select their files, e.g.:
--
--   -- create policy voltcore_files_rw on storage.objects
--   --   for all to authenticated
--   --   using (bucket_id = 'voltcore-files')
--   --   with check (bucket_id = 'voltcore-files');
