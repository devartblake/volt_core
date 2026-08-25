-- Let a tenant admin manage who belongs to the tenant and at what role.
--
-- The app has shipped a "Team & Roles" screen (/admin/technicians) since the
-- RBAC work, but it cannot actually write anything:
--
--   * tenant_members has RLS enabled and only a `members_read` SELECT policy.
--     With no INSERT/UPDATE policy every write is denied, so the role dropdown
--     fails with 42501 no matter who is signed in.
--   * user_profiles is readable only by its owner (`user_profiles_self`), so
--     an admin listing the team sees their own name and a column of
--     "Tenant member" placeholders with no email for everyone else.
--   * There is no way at all to grant a role to somebody who signed up but was
--     never added to the tenant — the screen can only edit rows that already
--     exist.
--
-- This migration closes all three. It changes no existing policy; everything
-- here is additive, and `user_profiles_self` keeps working exactly as before.

begin;

-- ---------------------------------------------------------------------------
-- 1. Admins may write tenant_members
-- ---------------------------------------------------------------------------
-- Bootstrapping note: these policies deliberately require an *existing* active
-- admin, so the first membership of a brand new tenant still cannot be created
-- from the client. That row is seeded out-of-band by
-- supabase/manual/tenant_bootstrap.sql, which runs with elevated rights.

grant select, insert, update, delete on public.tenant_members to authenticated;

drop policy if exists members_admin_insert on public.tenant_members;
create policy members_admin_insert
  on public.tenant_members
  for insert to authenticated
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

drop policy if exists members_admin_update on public.tenant_members;
create policy members_admin_update
  on public.tenant_members
  for update to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  )
  with check (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

drop policy if exists members_admin_delete on public.tenant_members;
create policy members_admin_delete
  on public.tenant_members
  for delete to authenticated
  using (
    (select public.has_tenant_role(tenant_id, array['admin'::public.app_role]))
  );

-- ---------------------------------------------------------------------------
-- 2. Admins may read the profiles of their own tenant's members
-- ---------------------------------------------------------------------------
-- Scoped to people who are already members of a tenant the caller administers.
-- It is not a directory of every user in the project: discovering somebody who
-- is *not* yet a member goes through the lookup function below instead.

drop policy if exists user_profiles_tenant_admin_read on public.user_profiles;
create policy user_profiles_tenant_admin_read
  on public.user_profiles
  for select to authenticated
  using (
    exists (
      select 1
      from public.tenant_members tm
      where tm.user_id = user_profiles.user_id
        and (
          select public.has_tenant_role(
            tm.tenant_id, array['admin'::public.app_role]
          )
        )
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Look up a not-yet-member by email
-- ---------------------------------------------------------------------------
-- Adding somebody to a tenant needs their user_id, and by definition no RLS
-- policy on user_profiles can expose them: they are not a member of anything
-- the admin can see. Hence a definer function.
--
-- It matches on the **whole** email and returns at most one row, so it answers
-- "is this specific person registered?" and cannot be used to enumerate or
-- prefix-search the user base. `is_member` lets the caller tell "not
-- registered" apart from "already on the team", which are different problems
-- with different fixes.

create or replace function public.admin_lookup_user_by_email(
  p_tenant_id uuid,
  p_email text
)
returns table (
  user_id uuid,
  display_name text,
  email text,
  phone text,
  is_active boolean,
  member_role public.app_role,
  is_member boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- Raise rather than return empty: an admin whose tenant context is
  -- misconfigured would otherwise be told the user does not exist, which sends
  -- them looking in entirely the wrong place.
  if not public.has_tenant_role(
    p_tenant_id, array['admin'::public.app_role]
  ) then
    raise exception using
      errcode = 'insufficient_privilege',
      message = 'Only an active admin of this tenant can look up users.';
  end if;

  return query
  select
    up.user_id,
    up.display_name,
    up.email,
    up.phone,
    up.is_active,
    tm.role,
    (tm.user_id is not null)
  from public.user_profiles up
  left join public.tenant_members tm
    on tm.user_id = up.user_id
   and tm.tenant_id = p_tenant_id
  where lower(btrim(up.email)) = lower(btrim(p_email))
  limit 1;
end
$$;

revoke all on function public.admin_lookup_user_by_email(uuid, text)
  from public, anon;
grant execute on function public.admin_lookup_user_by_email(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. A tenant must keep one active admin
-- ---------------------------------------------------------------------------
-- The controller already refuses to demote the last admin, but that check runs
-- on one device against a list it fetched earlier. Two admins demoting each
-- other at once both pass it. Enforce it where the race actually resolves.

create or replace function public.enforce_last_tenant_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid := coalesce(new.tenant_id, old.tenant_id);
  v_active_admins integer;
begin
  -- Deleting a tenant cascades to its memberships. There is no last admin to
  -- protect when the tenant itself is being removed.
  if not exists (select 1 from public.tenants where id = v_tenant_id) then
    return coalesce(new, old);
  end if;

  select count(*) into v_active_admins
  from public.tenant_members
  where tenant_id = v_tenant_id
    and is_active
    and role = 'admin'::public.app_role;

  if v_active_admins = 0 then
    raise exception using
      errcode = 'check_violation',
      message = 'A tenant must keep at least one active admin.';
  end if;

  return coalesce(new, old);
end
$$;

revoke all on function public.enforce_last_tenant_admin()
  from public, anon, authenticated;

drop trigger if exists trg_tenant_members_last_admin on public.tenant_members;
create trigger trg_tenant_members_last_admin
  after update or delete on public.tenant_members
  for each row execute function public.enforce_last_tenant_admin();

commit;
