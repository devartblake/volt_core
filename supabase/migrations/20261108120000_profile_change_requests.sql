-- Generator parts profile: change requests.
--
--   profile_change_requests   a technician's PROPOSED change to one
--                             generator's parts profile (asset_parts), waiting
--                             for a supervisor, dispatcher or admin to approve
--                             or reject it. The per-item changes (add / update
--                             / remove) live in the jsonb `changes` column.
--
-- Technicians still cannot write asset_parts (see
-- 20261106120000_materials_phase_a.sql). Approving a request is done by the
-- app, which saves the profile as the reviewer and then marks the request
-- approved here.
--
-- Who can do what:
--   any tenant member    INSERT a request for themselves (proposed_by =
--                        auth.uid(), not yet reviewed)
--   the proposer         SELECT their own; UPDATE only to withdraw a pending one
--   admin, supervisor,   SELECT every request in the tenant; UPDATE (approve /
--   dispatcher           reject)
--
-- The app saves rows with an upsert, and an upsert is checked against the
-- INSERT policy too, so the insert check also accepts the proposer's own
-- withdrawn row and a reviewer's row. Run once in the Supabase SQL editor.

begin;

create table if not exists public.profile_change_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,

  -- Same "make|model|serial" key as asset_parts.equipment_key.
  equipment_key text not null,
  make text not null default '',
  model text not null default '',
  serial_number text not null default '',

  proposed_by uuid not null references auth.users(id) on delete cascade,
  proposed_by_name text not null default '',
  -- Why the technician wants the change.
  note text not null default '',

  status text not null default 'pending',
  -- [{kind: add|update|remove, itemId, slot, ...}] - see ProfileItemChange in
  -- the app.
  changes jsonb not null default '[]'::jsonb,

  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_note text not null default '',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profile_change_requests_status_valid
    check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  constraint profile_change_requests_key_not_blank
    check (length(trim(equipment_key)) > 0)
);

create index if not exists idx_profile_change_requests_tenant_status
  on public.profile_change_requests (tenant_id, status, created_at desc);
create index if not exists idx_profile_change_requests_equipment
  on public.profile_change_requests (tenant_id, equipment_key);
create index if not exists idx_profile_change_requests_proposer
  on public.profile_change_requests (proposed_by);

drop trigger if exists trg_profile_change_requests_updated_at
  on public.profile_change_requests;
create trigger trg_profile_change_requests_updated_at
  before update on public.profile_change_requests
  for each row execute function public.set_updated_at();

alter table public.profile_change_requests enable row level security;

revoke all on public.profile_change_requests from anon;

-- Read: your own, or everything if you review requests.
drop policy if exists profile_change_requests_read
  on public.profile_change_requests;
create policy profile_change_requests_read on public.profile_change_requests
  for select to authenticated
  using (
    proposed_by = auth.uid()
    or public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
  );

-- Create: a member for themselves, pending (or already withdrawn, which is what
-- an upsert of a withdrawal presents); reviewers may write any row.
drop policy if exists profile_change_requests_insert
  on public.profile_change_requests;
create policy profile_change_requests_insert on public.profile_change_requests
  for insert to authenticated
  with check (
    public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
    or (
      public.is_tenant_member(tenant_id)
      and proposed_by = auth.uid()
      and status in ('pending', 'withdrawn')
      and reviewed_by is null
    )
  );

-- Reviewers approve or reject.
drop policy if exists profile_change_requests_review
  on public.profile_change_requests;
create policy profile_change_requests_review on public.profile_change_requests
  for update to authenticated
  using (
    public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
  )
  with check (
    public.has_tenant_role(
      tenant_id, array['admin', 'supervisor', 'dispatcher']::public.app_role[])
  );

-- The proposer may only withdraw their own pending request.
drop policy if exists profile_change_requests_withdraw
  on public.profile_change_requests;
create policy profile_change_requests_withdraw on public.profile_change_requests
  for update to authenticated
  using (
    proposed_by = auth.uid()
    and status = 'pending'
    and public.is_tenant_member(tenant_id)
  )
  with check (
    proposed_by = auth.uid()
    and status = 'withdrawn'
    and public.is_tenant_member(tenant_id)
  );

-- No delete policy: requests are kept as the record of who asked for what.

commit;
