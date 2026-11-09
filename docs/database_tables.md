# Database tables

What is in the Supabase `public` schema, whether the app uses it, and what to do about the older tables. Checked 2026-11-08 against the live project (row counts at that time) and a search of the app code for each table name.

**46 tables.** Every table has Row Level Security on, and every table is scoped to a company (`tenant_id`) except the user tables noted below.

## Summary

| Group | Tables | Verdict |
|---|---|---|
| In use, with data | 15 | Keep |
| In use by the app, empty so far | 12 (including `app_settings`) | Keep (the feature exists; no data entered yet) |
| Added by us in the last two weeks | 13 | Keep (see the inventory design doc) |
| **Unused or legacy, all empty** | **6** | See "Older tables" below |

## In use, with data

| Table | Rows | What it holds | Used by |
|---|---|---|---|
| `inspections` | 29 | Site inspections: site code, address, grade (green / amber / red), service date, technician, generator make / model / serial, checklist answers, next-due date | Inspections, dashboard, readiness, analytics |
| `equipment` | 24 | One row per generator: name, make, model, serial, voltage, site location, status, extra details in `metadata` | Equipment search, asset history |
| `maintenance_jobs` | 8 | Maintenance work: title, site, technician, scheduled / completed state, follow-up flag | Maintenance, Work |
| `maintenance_records` | 8 | The full maintenance form for each job, stored as one JSON `data` field | Maintenance |
| `schedule_tasks` | 1 | Scheduled visits: title, date and time, status, assignee, link to an inspection or maintenance job | Schedule, dashboard |
| `fleet_vehicles` | 2 | Vehicles (trucks): designation, plate, VIN, make, model, mileage, assigned driver | Fleet |
| `tenants` | 1 | Your company record | Everywhere |
| `tenant_members` | 4 | Who belongs to the company, their role (admin, supervisor, dispatcher, technician, apprentice) and optional division (`division_id`) | Sign-in, permissions |
| `user_profiles` | 4 | Display name, email, phone, avatar for each user | Admin, technician names |
| `tenant_role_assignments` | 3 | History of role changes (who changed whose role, when, why) | Admin |
| `form_templates` | 2 | Inspection form templates (name, type) | Templates |
| `form_template_revisions` | 2 | Versions of each template (draft / published) | Templates |
| `form_template_sections` | 16 | Sections inside a template revision | Templates |
| `form_template_fields` | 170 | Questions inside the sections: label, type, order | Templates |
| `form_template_field_options` | 53 | Answer choices for dropdown-style questions | Templates |

## In use by the app, empty so far

| Table | What it holds | Used by |
|---|---|---|
| `customers` | Customer records: name, legal name, contact, billing address | Customers & Sites screen |
| `sites` | Customer sites: site code, address, grade, notes | Customers & Sites screen |
| `work_orders` | Work orders: title, status, priority, customer, site, asset, assignee | Jobs (work orders) |
| `work_order_events` | Status history for work orders | Jobs |
| `nameplate_data` | Generator nameplate details per inspection (JSON) | Inspections |
| `form_responses` | Answers submitted on the newer form-template engine | Templates |
| `form_response_report_artifacts` | Generated reports for those responses | Templates |
| `tenant_retention_policies` | How many days archived records and reports are kept | Settings |
| `vehicle_asset_catalog` | Types of tools carried on vehicles | Fleet, Tool Catalog |
| `vehicle_assets` | The tool units on each vehicle and whether they are present | Fleet |
| `vehicle_maintenance_checks` | Vehicle oil, lubricant and mileage service checks | Fleet |
| `app_settings` | Company-wide key / value settings. The function `get_active_tenant_id()` reads the key `active_tenant` from it, so **do not remove it** | Database function |

## Added by us (2026-11-06 onward)

**Audit log (2026-11-12, migration `20261112100000_audit_log.sql`).** `audit_log` is append-only (a trigger refuses update and delete; only `purge_audit_log()` may remove rows older than 730 days, not scheduled) and readable by company admins only. Rows are written by the `SECURITY DEFINER` trigger function `log_row_change()` on: `inspections` (update, delete; ignores payload-only changes), `maintenance_jobs` (delete), `part_prices`, `vendors`, `inventory_locations`, `tenant_members` (insert, update, delete), `purchase_orders` (update, delete), `inventory_movements` (insert of adjust / count only), `user_profiles` (is_active / email changes), `profile_change_requests` (status change), `vehicle_inspections` (delete). Updates keep only the changed keys; values over 4 KB are stored as `[omitted]`.

**Divisions and the apprentice role (2026-11-13, migrations `20261113100000_apprentice_role.sql` then `20261113110000_divisions.sql`).** The enum `app_role` gains the value `apprentice` (a technician who cannot sign off or delete work; enforced in the app). New table `divisions` (`id`, `tenant_id`, `name` unique per company ignoring case, `sort_order`, `is_active`, timestamps with `set_updated_at`): any company member can read, only admins write. New nullable column `tenant_members.division_id` (references `divisions`, cleared if the division is deleted; a trigger refuses a division from another company) with a partial index. The audit log trigger on `tenant_members` records a division change without modification. The `inventory_movements` insert policy and `is_assigned_technician()` now accept `apprentice` wherever they accept `technician`. See section 24 of `materials_and_inventory_design.md`.

**Permission overrides (2026-11-14, migration `20261114100000_member_permission_overrides.sql`).** `member_permission_overrides` (`tenant_id`, `user_id`, `permission` text key from the app's fixed catalogue, `effect` 'allow' or 'deny', `updated_by`, timestamps with `set_updated_at`), primary key (`tenant_id`, `user_id`, `permission`). Admins of the company can read and write every row; a member can read only their own (`user_id = (select auth.uid())`); nothing else. The app applies it; row level security elsewhere still follows the role. Insert, update and delete are written to `audit_log` by `audit_member_permission_change()` (`audit_log.table_name` has no CHECK, so nothing else changed).

**Several divisions per person (2026-11-14, migration `20261114110000_member_divisions.sql`).** `member_divisions` (`tenant_id`, `user_id`, `division_id` references `divisions` on delete cascade, `created_at`), primary key (`user_id`, `division_id`); a trigger refuses a division from another company. Company members read, admins write. Existing `tenant_members.division_id` values were copied across; that column is now deprecated but kept for older app builds (the app keeps it equal to the first chosen division). Insert and delete are written to `audit_log` by `audit_member_division_change()`.

**Job cost functions (migration `20261112110000_job_costs.sql`).** `job_parts_cost(p_job_ref text)` and `job_costs_summary(p_since date)` return the parts cost of a job at the last paid price; admin only. See section 23 of `materials_and_inventory_design.md`.

`parts_catalog` (163 rows), `asset_parts` (260), `job_material_lines` (6), `inventory_locations` (1), `inventory_movements` (0), `vendors` (1), `part_prices` (0), `purchase_orders` (1), `purchase_order_lines` (1), `profile_change_requests` (0), `vehicle_inspections` (3). Described in `materials_and_inventory_design.md` and `fleet_and_vehicle_assets_plan.md`.

## Older tables: do we need them?

These came from the first version of the schema. Six are unused or legacy (the table below also lists `app_settings`, which is kept). **All are empty and small (16-48 KB each).**

| Table | What it was for | App code uses it? | Replaced by | Verdict |
|---|---|---|---|---|
| `maintenance_parts_used` | Parts listed on a maintenance job (category, label, part number, quantity) | No | `job_material_lines` (the design doc replaced it) | **Safe to drop** |
| `maintenance_attachments` | Metadata for files attached to maintenance jobs (bucket, path, size) | No (photos go straight to storage) | Storage files plus the app's own file backup | **Safe to drop** |
| `project_tasks` | A generic task list (title, summary, site, status, assignee) | No | `schedule_tasks` | **Safe to drop** |
| `test_intervals` | Load-test interval rows per inspection | No (the app keeps these on the device) | Local storage | **Safe to drop**, unless you plan to sync load tests |
| `technicians` | A separate list of technicians (name, email, phone, role, last activity) | **Yes, the admin screens still read and write it** | `tenant_members` + `user_profiles` | **Keep for now**; remove after the admin code is changed |
| `role_assignments` | Role-change history tied to `technicians` | **Yes, the admin code references it** | `tenant_role_assignments` | **Keep for now**, same as above |
| `app_settings` | Company settings (see above) | Only through a database function | n/a | **Keep** |

**Dropping is possible, but I would not rush it.** Reasons:
- Empty tables cost nothing and do not slow anything down.
- The only benefit is tidiness and fewer advisor warnings. Two of them, `maintenance_attachments` and `maintenance_parts_used`, account for 40 of the 147 "multiple policy" warnings. Those can be fixed by tidying their policies without dropping anything.
- A table is easy to add back, but anything you later wish you had kept is gone.

### What I suggest, in order

1. **Now (safe, no data at risk):** nothing needs to change. Leave all of them.
2. **When you want the advisor list shorter:** I write a migration that merges the duplicate policies on the unused tables. No table is dropped.
3. **Before real users:** take a database backup (Supabase daily backups, or a manual export), then drop the four "safe to drop" tables in one migration. I would write it with the table list and a rollback note.
4. **Later, with a code change:** point the admin screens at `tenant_members` and `user_profiles` only, then retire `technicians` and `role_assignments`.

Tell me which of steps 2-4 you want and I will write the migration (and the code change for step 4).
