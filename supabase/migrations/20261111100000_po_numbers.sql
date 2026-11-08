-- Purchase order numbers assigned by the server.
--
-- Problem: every device invented "PO-0001" locally, so two tablets collided on
-- unique (tenant_id, po_number) and the second order never synced.
--
-- Design (offline-first):
--   * The app creates a new order with a PROVISIONAL number "NEW-<8 chars of
--     the order id>" and shows "Number pending" until the real one arrives.
--   * po_counters keeps the last number handed out per tenant.
--   * A BEFORE INSERT/UPDATE trigger on purchase_orders replaces a provisional
--     number with the next real "PO-0001" number. A number the user typed
--     (anything not starting with "NEW-") is kept exactly as typed.
--   * If the order already exists (the app re-sends an upsert that still
--     carries the provisional number), the stored number is kept and no new
--     number is used up.
--   * The app's refreshFromCloud pulls the row back and adopts the number.
--
-- Functions:
--   public.next_po_number(p_tenant uuid) returns text    admin RPC, atomic
--   public.allocate_po_number(p_tenant uuid) returns text internal, no grants
--   public.assign_po_number() returns trigger
--
-- Numbers already typed by hand and larger than the counter are skipped, so a
-- manually typed PO-0050 never collides with a generated one. Gaps can occur
-- (a rolled-back insert rolls its number back, but a deleted draft leaves a
-- gap); numbers never repeat. Idempotent: safe to run more than once.

begin;

create table if not exists public.po_counters (
  tenant_id uuid primary key references public.tenants(id) on delete cascade,
  last_number integer not null default 0,
  constraint po_counters_nonneg check (last_number >= 0)
);

alter table public.po_counters enable row level security;
revoke all on public.po_counters from anon, authenticated;
-- No policies: only the SECURITY DEFINER functions below touch the table.

-- Seed from the highest existing PO-#### number per tenant.
insert into public.po_counters (tenant_id, last_number)
select po.tenant_id,
       max(substring(po.po_number from '^[Pp][Oo]-([0-9]+)$')::integer)
from public.purchase_orders po
where po.po_number ~* '^PO-[0-9]{1,9}$'
group by po.tenant_id
on conflict (tenant_id) do update
  set last_number = greatest(public.po_counters.last_number, excluded.last_number);

-- Internal: take the next free number. Not callable by clients.
create or replace function public.allocate_po_number(p_tenant uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  n integer;
  candidate text;
begin
  loop
    insert into public.po_counters as c (tenant_id, last_number)
    values (p_tenant, 1)
    on conflict (tenant_id) do update set last_number = c.last_number + 1
    returning c.last_number into n;

    candidate := 'PO-' || lpad(n::text, 4, '0');
    -- Skip a number someone typed by hand.
    exit when not exists (
      select 1 from public.purchase_orders po
      where po.tenant_id = p_tenant
        and lower(po.po_number) = lower(candidate)
    );
  end loop;
  return candidate;
end;
$$;

revoke all on function public.allocate_po_number(uuid) from public, anon, authenticated;

-- Client RPC: the next number for the tenant. Admin only.
create or replace function public.next_po_number(p_tenant uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null
     or not public.has_tenant_role(p_tenant, array['admin']::public.app_role[]) then
    raise exception 'Only an admin can get a purchase order number.'
      using errcode = '42501';
  end if;
  return public.allocate_po_number(p_tenant);
end;
$$;

revoke all on function public.next_po_number(uuid) from public, anon;
grant execute on function public.next_po_number(uuid) to authenticated;

-- Trigger: swap a provisional number for the real one.
create or replace function public.assign_po_number()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  existing text;
begin
  if new.po_number is null or new.po_number !~ '^NEW-' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Never push a provisional number over a stored one.
    if old.po_number !~ '^NEW-' then
      new.po_number := old.po_number;
      return new;
    end if;
  else
    -- An upsert of an order that is already stored: keep its number.
    select po.po_number into existing
    from public.purchase_orders po
    where po.id = new.id and po.po_number !~ '^NEW-';
    if existing is not null then
      new.po_number := existing;
      return new;
    end if;
  end if;

  new.po_number := public.allocate_po_number(new.tenant_id);
  return new;
end;
$$;

revoke all on function public.assign_po_number() from public, anon, authenticated;

drop trigger if exists trg_purchase_orders_assign_number on public.purchase_orders;
create trigger trg_purchase_orders_assign_number
  before insert or update of po_number on public.purchase_orders
  for each row execute function public.assign_po_number();

commit;
