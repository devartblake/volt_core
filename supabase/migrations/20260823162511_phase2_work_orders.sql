-- Voltcore FieldOps Phase 2: durable, tenant-scoped work orders and history.
--
-- Work orders are written offline first by the Flutter client and then upserted
-- through the sync outbox.  The history table is deliberately trigger-owned:
-- clients can read it but cannot forge audit entries.

begin;

create table if not exists public.work_orders (
  id uuid primary key,
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  title text not null,
  status text not null default 'draft',
  priority text not null default 'normal',
  customer_id uuid,
  site_id uuid,
  asset_id uuid,
  -- This remains an auth user id. The legacy technician directory is not yet
  -- tenant-owned, so it is not a safe foreign-key target for this table.
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  scheduled_for timestamptz,
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint work_orders_title_not_blank check (length(trim(title)) > 0),
  constraint work_orders_status_valid
    check (status in ('draft', 'scheduled', 'inProgress', 'completed', 'cancelled')),
  constraint work_orders_priority_valid
    check (priority in ('low', 'normal', 'high', 'urgent')),
  constraint work_orders_scheduled_status_check
    check (status <> 'scheduled' or scheduled_for is not null),
  constraint work_orders_tenant_id_id_unique unique (tenant_id, id)
);

-- Tenant-composite foreign keys prevent cross-tenant customer/site/asset links.
create unique index if not exists idx_equipment_tenant_id_id
  on public.equipment (tenant_id, id);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'work_orders_tenant_customer_fk'
      and conrelid = 'public.work_orders'::regclass
  ) then
    alter table public.work_orders add constraint work_orders_tenant_customer_fk
      foreign key (tenant_id, customer_id)
      references public.customers (tenant_id, id) on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'work_orders_tenant_site_fk'
      and conrelid = 'public.work_orders'::regclass
  ) then
    alter table public.work_orders add constraint work_orders_tenant_site_fk
      foreign key (tenant_id, site_id)
      references public.sites (tenant_id, id) on delete restrict;
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'work_orders_tenant_asset_fk'
      and conrelid = 'public.work_orders'::regclass
  ) then
    alter table public.work_orders add constraint work_orders_tenant_asset_fk
      foreign key (tenant_id, asset_id)
      references public.equipment (tenant_id, id) on delete restrict;
  end if;
end $$;

create index if not exists idx_work_orders_tenant_updated
  on public.work_orders (tenant_id, updated_at desc);
create index if not exists idx_work_orders_tenant_status_schedule
  on public.work_orders (tenant_id, status, scheduled_for)
  where status in ('draft', 'scheduled', 'inProgress');
create index if not exists idx_work_orders_tenant_assignee_schedule
  on public.work_orders (tenant_id, assigned_to_user_id, scheduled_for)
  where assigned_to_user_id is not null;
create index if not exists idx_work_orders_tenant_site
  on public.work_orders (tenant_id, site_id) where site_id is not null;

drop trigger if exists trg_work_orders_updated_at on public.work_orders;
create trigger trg_work_orders_updated_at
  before update on public.work_orders
  for each row execute function public.set_updated_at();

create table if not exists public.work_order_events (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id) on delete cascade,
  work_order_id uuid not null,
  event_type text not null,
  actor_user_id uuid references auth.users(id) on delete set null,
  from_status text,
  to_status text,
  previous_assigned_to_user_id uuid references auth.users(id) on delete set null,
  assigned_to_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),

  constraint work_order_events_type_valid
    check (event_type in ('created', 'status_changed', 'assignment_changed')),
  constraint work_order_events_tenant_work_order_fk
    foreign key (tenant_id, work_order_id)
    references public.work_orders (tenant_id, id) on delete cascade
);

create index if not exists idx_work_order_events_tenant_work_order_created
  on public.work_order_events (tenant_id, work_order_id, created_at desc);

-- The function has no client API: it runs only as an AFTER trigger and records
-- the authenticated actor at the database boundary. A sync worker using a
-- service role will create an event with a null actor rather than trusting a
-- client-supplied identity.
create or replace function public.record_work_order_event()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.work_order_events (
      tenant_id, work_order_id, event_type, actor_user_id, to_status,
      assigned_to_user_id
    ) values (
      new.tenant_id, new.id, 'created', auth.uid(), new.status,
      new.assigned_to_user_id
    );
    return new;
  end if;

  if old.status is distinct from new.status then
    insert into public.work_order_events (
      tenant_id, work_order_id, event_type, actor_user_id, from_status,
      to_status
    ) values (
      new.tenant_id, new.id, 'status_changed', auth.uid(), old.status,
      new.status
    );
  end if;

  if old.assigned_to_user_id is distinct from new.assigned_to_user_id then
    insert into public.work_order_events (
      tenant_id, work_order_id, event_type, actor_user_id,
      previous_assigned_to_user_id, assigned_to_user_id
    ) values (
      new.tenant_id, new.id, 'assignment_changed', auth.uid(),
      old.assigned_to_user_id, new.assigned_to_user_id
    );
  end if;

  return new;
end;
$$;

drop trigger if exists trg_work_order_event_insert on public.work_orders;
create trigger trg_work_order_event_insert
  after insert on public.work_orders
  for each row execute function public.record_work_order_event();

drop trigger if exists trg_work_order_event_update on public.work_orders;
create trigger trg_work_order_event_update
  after update of status, assigned_to_user_id on public.work_orders
  for each row execute function public.record_work_order_event();

revoke all on function public.record_work_order_event() from public, anon, authenticated;

alter table public.work_orders enable row level security;
alter table public.work_order_events enable row level security;

drop policy if exists work_orders_read on public.work_orders;
drop policy if exists work_orders_insert on public.work_orders;
drop policy if exists work_orders_update on public.work_orders;
create policy work_orders_read on public.work_orders for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));
create policy work_orders_insert on public.work_orders for insert to authenticated
  with check ((select public.is_tenant_member(tenant_id)));
create policy work_orders_update on public.work_orders for update to authenticated
  using ((select public.is_tenant_member(tenant_id)))
  with check ((select public.is_tenant_member(tenant_id)));

drop policy if exists work_order_events_read on public.work_order_events;
create policy work_order_events_read on public.work_order_events for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

revoke all on public.work_orders, public.work_order_events from anon, authenticated;
grant select, insert, update on public.work_orders to authenticated;
grant select on public.work_order_events to authenticated;

commit;
