-- Phase 3 certification hardening: cover report-artifact foreign keys flagged
-- by the Supabase performance advisor.

begin;

create index if not exists idx_form_report_artifacts_tenant_revision
  on public.form_response_report_artifacts (tenant_id, template_revision_id);

create index if not exists idx_form_report_artifacts_created_by
  on public.form_response_report_artifacts (created_by_user_id)
  where created_by_user_id is not null;

commit;
