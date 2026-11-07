-- Inventory, phase C: job reservations, issue and return.
-- See docs/materials_and_inventory_design.md.
--
-- Phase B let only admins write to the ledger. Phase C lets supervisors and
-- dispatchers set parts aside for a job (reserve / release), take them out
-- (issue) and take returns. Receiving stock, adjusting and counting stay
-- admin-only. Job movements must name the job they are for.

begin;

drop policy if exists inventory_movements_insert on public.inventory_movements;
create policy inventory_movements_insert on public.inventory_movements
  for insert to authenticated
  with check (
    -- Admins: any movement.
    public.has_tenant_role(tenant_id, array['admin']::public.app_role[])
    or (
      -- Supervisors and dispatchers: job movements only.
      public.has_tenant_role(
        tenant_id,
        array['supervisor', 'dispatcher']::public.app_role[]
      )
      and reason in ('reserve', 'release', 'issue', 'return')
      and job_ref is not null
    )
  );

commit;
