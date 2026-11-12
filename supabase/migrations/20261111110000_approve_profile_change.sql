-- Atomic approval of a generator parts-profile change request.
--
-- Before: the app saved the generator's profile (asset_parts) and then, in a
-- second step, marked the request approved. A crash in between left the
-- profile changed but the request still pending.
--
-- Now one transaction does both:
--
--   public.approve_profile_change(p_request_id uuid, p_items jsonb,
--                                 p_review_note text default '') returns void
--   public.reject_profile_change(p_request_id uuid,
--                                p_review_note text default '') returns void
--
-- The app works out the new item list with its own Dart ProfileChanges
-- .applyChanges (the rules for stale / already-applied changes are NOT
-- repeated here) and sends the finished list as p_items. This function only
-- swaps it in.
--
-- p_items: a json array of objects with the asset_parts columns
--   id (uuid), slot_type, role, sort_order, part_number, part_name,
--   manufacturer, quantity, date_used (yyyy-mm-dd or null), notes.
-- tenant_id, equipment_key, make, model, serial_number are taken from the
-- REQUEST, never from the items, and updated_by is the caller. An item id that
-- already belongs to a different generator or tenant makes the whole call fail
-- (primary-key violation) and nothing changes.
--
-- Errors (SQLSTATE P0001 unless noted; the HINT is machine readable):
--   not signed in / wrong role        42501
--   request not found                 P0002   hint 'not_found'
--   request not pending               P0001   hint 'status:<current status>'
--   p_items not a json array          22023
-- The app treats hint 'status:approved' as success (already approved).
--
-- Only admin, supervisor and dispatcher of the request's tenant may call it.
-- Idempotent: safe to run more than once.

begin;

create or replace function public.approve_profile_change(
  p_request_id uuid,
  p_items jsonb,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  req public.profile_change_requests%rowtype;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in to approve a profile change.' using errcode = '42501';
  end if;

  select * into req
  from public.profile_change_requests r
  where r.id = p_request_id
  for update;

  if not found then
    raise exception 'Profile change request not found.'
      using errcode = 'P0002', hint = 'not_found';
  end if;

  if not public.has_tenant_role(
       req.tenant_id,
       array['admin', 'supervisor', 'dispatcher']::public.app_role[]) then
    raise exception 'You cannot approve profile changes.' using errcode = '42501';
  end if;

  if req.status <> 'pending' then
    raise exception 'This request is already %, not pending.', req.status
      using errcode = 'P0001', hint = 'status:' || req.status;
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array.' using errcode = '22023';
  end if;

  delete from public.asset_parts ap
  where ap.tenant_id = req.tenant_id
    and ap.equipment_key = req.equipment_key;

  insert into public.asset_parts (
    id, tenant_id, equipment_key, make, model, serial_number,
    slot_type, role, sort_order, part_number, part_name, manufacturer,
    quantity, date_used, notes, updated_by
  )
  select
    x.id, req.tenant_id, req.equipment_key, req.make, req.model,
    req.serial_number,
    x.slot_type, coalesce(x.role, 'none'), coalesce(x.sort_order, 0),
    coalesce(x.part_number, ''), coalesce(x.part_name, ''),
    coalesce(x.manufacturer, ''), coalesce(x.quantity, 1), x.date_used,
    coalesce(x.notes, ''), uid
  from jsonb_to_recordset(p_items) as x(
    id uuid,
    slot_type text,
    role text,
    sort_order integer,
    part_number text,
    part_name text,
    manufacturer text,
    quantity integer,
    date_used date,
    notes text
  );

  update public.profile_change_requests r
  set status = 'approved',
      reviewed_by = uid,
      reviewed_at = now(),
      review_note = coalesce(p_review_note, '')
  where r.id = req.id;
end;
$$;

revoke all on function public.approve_profile_change(uuid, jsonb, text) from public, anon;
grant execute on function public.approve_profile_change(uuid, jsonb, text) to authenticated;

create or replace function public.reject_profile_change(
  p_request_id uuid,
  p_review_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  req public.profile_change_requests%rowtype;
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Sign in to reject a profile change.' using errcode = '42501';
  end if;

  select * into req
  from public.profile_change_requests r
  where r.id = p_request_id
  for update;

  if not found then
    raise exception 'Profile change request not found.'
      using errcode = 'P0002', hint = 'not_found';
  end if;

  if not public.has_tenant_role(
       req.tenant_id,
       array['admin', 'supervisor', 'dispatcher']::public.app_role[]) then
    raise exception 'You cannot reject profile changes.' using errcode = '42501';
  end if;

  if req.status <> 'pending' then
    raise exception 'This request is already %, not pending.', req.status
      using errcode = 'P0001', hint = 'status:' || req.status;
  end if;

  update public.profile_change_requests r
  set status = 'rejected',
      reviewed_by = uid,
      reviewed_at = now(),
      review_note = coalesce(p_review_note, '')
  where r.id = req.id;
end;
$$;

revoke all on function public.reject_profile_change(uuid, text) from public, anon;
grant execute on function public.reject_profile_change(uuid, text) to authenticated;

commit;
