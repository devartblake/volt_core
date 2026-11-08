-- Job cost: what the parts issued to a job cost, at the last price paid.
-- Admin only (prices are company costs).
--
--   public.job_parts_cost(p_job_ref text)
--     per part: net issued quantity (issued less returned; the ledger stores an
--     issue as a negative and a return as a positive, so it is -sum(qty_delta)) for one job, the
--     last PAID unit price (latest part_prices row with kind = 'paid', by
--     priced_on then created_at), and the line total. priced = false and
--     unit_cents null when the part has no paid price.
--
--   public.job_costs_summary(p_since date default null)
--     one row per job that had parts issued since the date (all time when
--     null): number of parts, total cost, and how many parts are unpriced.
--     Totals cover everything issued to those jobs, not only since the date.
--
-- The app computes the same figures on the device from the ledger and prices
-- it already holds (domain/job_cost.dart); these functions are for reports and
-- the server.
--
-- Idempotent.

begin;

create or replace function public.job_parts_cost(p_job_ref text)
returns table (
  part_id uuid,
  part_number text,
  name text,
  qty_issued int,
  unit_cents int,
  line_cents bigint,
  priced boolean
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_tenant uuid;
begin
  select tm.tenant_id into v_tenant
    from public.tenant_members tm
   where tm.user_id = auth.uid()
     and tm.is_active
     and tm.role = 'admin'
   order by tm.created_at
   limit 1;

  if v_tenant is null
     or not public.has_tenant_role(v_tenant, array['admin']::public.app_role[]) then
    raise exception 'Only an admin can read job costs.'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  with net as (
    select m.part_id as pid,
           sum(-m.qty_delta)::int as qty
      from public.inventory_movements m
     where m.tenant_id = v_tenant
       and m.job_ref = p_job_ref
       and m.reason in ('issue', 'return')
     group by m.part_id
  )
  select pc.id,
         pc.part_number,
         pc.name,
         greatest(n.qty, 0),
         lp.unit_price_cents,
         (greatest(n.qty, 0)::bigint * coalesce(lp.unit_price_cents, 0)),
         (lp.unit_price_cents is not null)
    from net n
    join public.parts_catalog pc
      on pc.id = n.pid and pc.tenant_id = v_tenant
    left join lateral (
      select pp.unit_price_cents
        from public.part_prices pp
       where pp.tenant_id = v_tenant
         and pp.part_id = n.pid
         and pp.kind = 'paid'
       order by pp.priced_on desc, pp.created_at desc
       limit 1
    ) lp on true
   where n.qty > 0
   order by pc.part_number;
end;
$$;

revoke all on function public.job_parts_cost(text) from public, anon;
grant execute on function public.job_parts_cost(text) to authenticated;

create or replace function public.job_costs_summary(p_since date default null)
returns table (
  job_ref text,
  parts int,
  total_cents bigint,
  unpriced_parts int
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
#variable_conflict use_column
declare
  v_tenant uuid;
begin
  select tm.tenant_id into v_tenant
    from public.tenant_members tm
   where tm.user_id = auth.uid()
     and tm.is_active
     and tm.role = 'admin'
   order by tm.created_at
   limit 1;

  if v_tenant is null
     or not public.has_tenant_role(v_tenant, array['admin']::public.app_role[]) then
    raise exception 'Only an admin can read job costs.'
      using errcode = 'insufficient_privilege';
  end if;

  return query
  with jobs as (
    select distinct m.job_ref as jref
      from public.inventory_movements m
     where m.tenant_id = v_tenant
       and m.job_ref is not null
       and m.reason = 'issue'
       and (p_since is null or m.at >= p_since::timestamptz)
  ),
  net as (
    select m.job_ref as jref,
           m.part_id as pid,
           sum(-m.qty_delta) as qty
      from public.inventory_movements m
      join jobs j on j.jref = m.job_ref
     where m.tenant_id = v_tenant
       and m.reason in ('issue', 'return')
     group by m.job_ref, m.part_id
    having sum(-m.qty_delta) > 0
  ),
  priced as (
    select n.jref,
           n.pid,
           n.qty,
           lp.unit_price_cents as cents
      from net n
      left join lateral (
        select pp.unit_price_cents
          from public.part_prices pp
         where pp.tenant_id = v_tenant
           and pp.part_id = n.pid
           and pp.kind = 'paid'
         order by pp.priced_on desc, pp.created_at desc
         limit 1
      ) lp on true
  )
  select p.jref,
         count(*)::int,
         coalesce(sum(p.qty::bigint * coalesce(p.cents, 0)), 0)::bigint,
         (count(*) filter (where p.cents is null))::int
    from priced p
   group by p.jref
   order by 3 desc, 1;
end;
$$;

revoke all on function public.job_costs_summary(date) from public, anon;
grant execute on function public.job_costs_summary(date) to authenticated;

commit;
