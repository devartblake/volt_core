# Remaining tasks

Last updated 2026-11-10. This lists what is still open, who owns it, and the decisions already made. Detail lives in the design docs linked from [README.md](README.md).

## Decisions recorded

| Topic | Decision |
|---|---|
| Inspection "finished" | Counted as finished only when the **post-inspection checklist is at least 50% complete** and the **Parts & Materials list has a part number for each of: air filter, fuel filter, oil or lube filter, coolant filter, battery**. Saving a draft is always allowed. |
| Deleting inspections | **Admins and dispatchers** only (supervisors and technicians cannot). |
| Vehicle inspection reads | Restricted: managers (admin, supervisor, dispatcher), the inspector, or the vehicle's assigned user. |
| Part names | The part "name" is a free-text **description**. Part photos are wanted in the part bottom sheet. |
| Zapier / BusyBusy | On hold until BusyBusy answers what its API and Zapier actions allow (see below). |
| Leaked-password protection | Owner: you. |

## A. In progress (code)

| Task | Status |
|---|---|
| Inspection finish rule (50% checklist plus five part requirements), and delete limited to admins and dispatchers | Being built; includes a migration for the cloud delete policy if the existing one does not match |
| Part descriptions, "clean up generic names" action, and a product image in the part bottom sheet (attach, store, sync, show) | Being built; includes a migration for the image column and storage |
| **Generator Fleet Readiness dashboard** | Built (stage 1 rules, stage 2 screens); see [fleet_readiness.md](fleet_readiness.md) and the known gaps in section E |

## B. SQL for you to run (in the Supabase SQL editor)

| File | What it does | State |
|---|---|---|
| `20261110120000_housekeeping_policies_and_indexes.sql` | Restricts who can read vehicle inspections; makes four row-level-security policies evaluate once per query; splits the inventory locations write policy; adds 17 foreign-key indexes | **to run** |
| `20261110100000_inspections_delete_policy.sql` | Inspection delete in the cloud for admins and dispatchers only (today supervisors can also delete) | pending, written by the finish-rule task if needed |
| `20261110110000_part_images.sql` | `image_path` on parts, plus any storage bucket step | pending, written by the part-image task |

## C. Your tasks

- **Stock and pricing data.** All imported parts show 0 on hand. Enter opening counts, minimums, vendors and prices.
- **Unimported spreadsheet data.** You are working on it. The generator details are probably on the first sheet ("Materials Tracking", free text per site). Three generators (Q313, Q680, Q419) have no make, model or serial, so they have no parts list yet. When the data is ready, ask for an import for it.
- **Part descriptions.** Once the editor shows "Description", replace the generic names (or run the cleanup action first).
- **BusyBusy.** Ask BusyBusy: is there a public API with write access? Which Zapier triggers and actions exist (only "Archive cost code" and "Archive employee" were found as actions)? Which plan is needed? Then decide which data flows each way (suggestion: projects, employees and cost codes in; completed jobs out).
- **Supabase leaked-password protection:** yours. Also rotate the two passwords that appeared in an earlier chat.
- **Technician sign-in for testing.** The dev credentials file is empty. Fill in the technician entries in `dev_credentials.local.json` (it is git-ignored) so Mark used and profile proposals can be tested as a technician.
- **Save one real vehicle inspection** on a truck to confirm vehicle inspections upload end to end (the table exists; nothing has been uploaded yet because none has been saved).

## D. Bigger features not started

From `generator_management_research.md`:

1. ~~**Generator Fleet Readiness dashboard**~~ Done (route `/readiness`, see [fleet_readiness.md](fleet_readiness.md)).
2. **Job costing** from prices: each job's parts cost (issued quantity x last price paid), on the job and in reports. Prices and issue movements now exist.
3. **Compliance calendar**: weekly, monthly and annual recurring checks for emergency generators with reminders before the due date. Confirm the intervals against NFPA 110 and your contracts first.
4. **Run-hour or date maintenance triggers**: record engine hours at each service and flag units due by hours as well as by date.
5. **Remote monitoring**: needs controller data and hardware; not recommended unless customers ask.
6. **BusyBusy integration** (Zapier and/or API): blocked on section C.

## E. Known gaps in what is built

| Area | Gap |
|---|---|
| Truck stock | "Own truck first" is enforced in the app only; a technician can write issue / return movements for any location. |
| Mark used | Removing an item already marked used does not reverse its stock; changing the quantity afterwards does not update the ledger; work orders have no Mark used. |
| Purchase orders | No adding a line after creation; share is text only, no PDF. |
| Profile approvals | Approving is two steps (save profile, then mark approved); a crash between them leaves the request pending (a second approve closes it as "already applied"). The waiting-approvals count is not on the dashboard yet. |
| Vehicle inspections | A second device sees the record but its signature and photo file paths point at the first device's files. If a stored inspector id is not a real user id, that upload is rejected. |
| Login | Dev sign-in code in `auth_controller.dart` is gated only by the build flag (the login button itself is debug-only). |
| Settings | Keeps an "Advanced" group outside the five planned groups. |
| Page transitions | Not checked on a device; a section change that keeps the old page underneath may slide instead of fading. |
| Not viewed on a tablet yet | Orders, Locations and transfers, Movements and usage report, Parts approvals, schedule Day / Week, equipment two-pane, Documents hub, new Settings and login, signature pads in dark mode, lazy lists. |
| Generator Fleet Readiness | Load-test dates are inferred from inspections with the load bank switch on (no dedicated date exists); borough only for `Q_` and `X_` site codes; the units list has no paging beyond lazy building; saved filter presets and a Documents hub "Generator Fleet Readiness" type filter are not built (the PDF is listed under Other); "Create maintenance job" needs the inspection to be on the device and opens the existing flow's own date picker; the due-bar tap targets are narrower than 48 dp (chips cover the same filters); filters are remembered for the session only; not viewed on a device or tablet. |
| Documents / inspections history | Not paged; the Documents hub and inspections lists load everything. |

## F. Security and performance review (Supabase advisors, 2026-11-10)

Reviewed with the Supabase security and performance advisors.

**Security**
- *Leaked password protection disabled*: yours (see section C).
- *14 functions marked "SECURITY DEFINER" that signed-in users can call*: these are mostly the helpers the row-level-security policies use (`is_tenant_member`, `has_tenant_role`, `can_manage_tenant_work`, `get_active_tenant_id`...), which is intended. Candidates to review for removal of `EXECUTE` from signed-in users: `admin_lookup_user_by_email`, `get_tech_dashboard_stats`, `publish_form_template_revision`, `save_form_template_draft`, `storage_job_id`, `storage_tenant_id`. Check each against the app before changing anything: the app may call them.
- *`inspections_update` allows any tenant member to update any inspection* and there are two overlapping insert policies (`inspections_insert`, `inspections_write`). Worth tightening; not changed yet because it affects every role's editing.

**Performance**
- *Fixed by the housekeeping migration:* four policies re-evaluating `auth.uid()` per row, a duplicate select policy on inventory locations, and 17 unindexed foreign keys on the tables we added.
- *Left alone:* about 40 more unindexed foreign keys and 148 "multiple permissive policies" warnings on older tables (maintenance, forms, equipment, app settings), and 65 unused indexes (an unused index is only worth dropping after real usage data exists).
- `profile_change_requests` still has two UPDATE policies (review and withdraw); merging them would change who can do what, so it is unchanged.

## G. Housekeeping

- `test/inspections/pdf_export_test.dart` was flaky inside the full suite (sync queue wrote into a deleted temp folder). The test now waits for background writes before cleaning up; it needs confirming over a few full-suite runs.
- Not committed on purpose: `.mcp.json` (your change; it removes `read_only=true` from the Supabase connection) and `assets/Shop Steward Procurement Tracker.xlsx` (business data).
- Nothing has been pushed to GitHub.
