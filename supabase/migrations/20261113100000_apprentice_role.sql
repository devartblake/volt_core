-- Apprentice role, step 1 of 2: add the enum value.
--
-- Adds 'apprentice' to public.app_role. An apprentice is a technician who
-- cannot sign off or delete work (the app enforces that; see
-- docs/materials_and_inventory_design.md, section "Roles").
--
-- Run order: this file FIRST, then 20261113110000_divisions.sql.
--
-- This file has NO begin/commit wrapper on purpose. Postgres cannot use a new
-- enum value in the same transaction that added it, so everything that
-- mentions 'apprentice' lives in the next file, which runs as its own
-- transaction after this one has committed. Idempotent.

alter type public.app_role add value if not exists 'apprentice';
