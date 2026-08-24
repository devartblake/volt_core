-- Voltcore FieldOps Phase 3: immutable generated-report artifacts.
--
-- A report is derived from one completed, immutable form response. The client
-- supplies only the response id and file metadata; a trigger copies tenant,
-- revision, and downstream business links from the response so those links
-- cannot drift or be fabricated independently of the source record.

begin;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'form_responses_tenant_id_id_unique'
      and conrelid = 'public.form_responses'::regclass
  ) then
    alter table public.form_responses
      add constraint form_responses_tenant_id_id_unique
      unique (tenant_id, id);
  end if;
end $$;

create table if not exists public.form_response_report_artifacts (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  response_id uuid not null,
  template_revision_id uuid not null,

  customer_id uuid,
  site_id uuid,
  asset_id uuid,
  work_order_id uuid,
  inspection_id uuid,
  maintenance_record_id uuid,

  storage_path text not null,
  file_name text not null,
  media_type text not null default 'application/pdf',
  byte_size bigint not null,
  checksum_sha256 text,
  created_by_user_id uuid default auth.uid()
    references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),

  constraint form_response_report_artifacts_path_not_blank
    check (length(trim(storage_path)) > 0),
  constraint form_response_report_artifacts_file_name_not_blank
    check (length(trim(file_name)) > 0),
  constraint form_response_report_artifacts_media_type_not_blank
    check (length(trim(media_type)) > 0),
  constraint form_response_report_artifacts_byte_size_nonnegative
    check (byte_size >= 0),
  constraint form_response_report_artifacts_checksum_valid
    check (
      checksum_sha256 is null
      or checksum_sha256 ~ '^[0-9a-fA-F]{64}$'
    ),
  constraint form_response_report_artifacts_tenant_response_fk
    foreign key (tenant_id, response_id)
    references public.form_responses (tenant_id, id) on delete restrict,
  constraint form_response_report_artifacts_tenant_revision_fk
    foreign key (tenant_id, template_revision_id)
    references public.form_template_revisions (tenant_id, id) on delete restrict
);

create index if not exists idx_form_report_artifacts_tenant_response_created
  on public.form_response_report_artifacts (tenant_id, response_id, created_at desc);
create index if not exists idx_form_report_artifacts_tenant_customer_created
  on public.form_response_report_artifacts (tenant_id, customer_id, created_at desc)
  where customer_id is not null;
create index if not exists idx_form_report_artifacts_tenant_site_created
  on public.form_response_report_artifacts (tenant_id, site_id, created_at desc)
  where site_id is not null;
create index if not exists idx_form_report_artifacts_tenant_asset_created
  on public.form_response_report_artifacts (tenant_id, asset_id, created_at desc)
  where asset_id is not null;
create index if not exists idx_form_report_artifacts_tenant_work_order_created
  on public.form_response_report_artifacts (tenant_id, work_order_id, created_at desc)
  where work_order_id is not null;
create index if not exists idx_form_report_artifacts_tenant_inspection_created
  on public.form_response_report_artifacts (tenant_id, inspection_id, created_at desc)
  where inspection_id is not null;
create index if not exists idx_form_report_artifacts_tenant_maintenance_created
  on public.form_response_report_artifacts (
    tenant_id,
    maintenance_record_id,
    created_at desc
  ) where maintenance_record_id is not null;

create or replace function public.populate_form_response_report_links()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
declare
  source_response public.form_responses%rowtype;
begin
  select *
    into source_response
    from public.form_responses
    where id = new.response_id;

  if not found then
    raise exception 'Form response % does not exist.', new.response_id;
  end if;

  if source_response.status <> 'completed' then
    raise exception 'Reports may only be linked to completed form responses.';
  end if;

  new.tenant_id := source_response.tenant_id;
  new.template_revision_id := source_response.template_revision_id;
  new.customer_id := source_response.customer_id;
  new.site_id := source_response.site_id;
  new.asset_id := source_response.asset_id;
  new.work_order_id := source_response.work_order_id;
  new.inspection_id := source_response.inspection_id;
  new.maintenance_record_id := source_response.maintenance_record_id;

  return new;
end;
$$;

revoke all on function public.populate_form_response_report_links()
  from public, anon, authenticated;

drop trigger if exists trg_form_response_report_links
  on public.form_response_report_artifacts;
create trigger trg_form_response_report_links
  before insert on public.form_response_report_artifacts
  for each row execute function public.populate_form_response_report_links();

revoke all on public.form_response_report_artifacts from anon, authenticated;
grant select, insert on public.form_response_report_artifacts to authenticated;

alter table public.form_response_report_artifacts enable row level security;

drop policy if exists form_response_report_artifacts_read
  on public.form_response_report_artifacts;
drop policy if exists form_response_report_artifacts_insert
  on public.form_response_report_artifacts;

create policy form_response_report_artifacts_read
  on public.form_response_report_artifacts
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

create policy form_response_report_artifacts_insert
  on public.form_response_report_artifacts
  for insert to authenticated
  with check ((select public.is_tenant_member(tenant_id)));

commit;
