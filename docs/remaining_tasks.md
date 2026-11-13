# Remaining tasks

Last updated 2026-11-12. This lists what is still open, who owns it, and the decisions already made. Detail lives in the design docs linked from [README.md](README.md). A tour of the screens is in [app_tour.md](app_tour.md).

## Decisions recorded

| Topic | Decision |
|---|---|
| Inspection "finished" | Counted as finished only when the **post-inspection checklist is at least 50% complete** and the **Parts & Materials list has a part number for each of: air filter, fuel filter, oil or lube filter, coolant filter, battery**. Saving a draft is always allowed. |
| Deleting inspections | **Admins and dispatchers** only (supervisors and technicians cannot). |
| Vehicle inspection reads | Restricted: managers (admin, supervisor, dispatcher), the inspector, or the vehicle's assigned user. |
| Part names | The part "name" is a free-text **description**. Part photos are wanted in the part bottom sheet. |
| Apprentice role | A technician who **cannot sign off or delete work**. Same screens and stock access as a technician. Enforced in the app only. |
| Divisions | A **company-defined list** managed by admins; any user can be in **more than one**; a label only (no data restriction). |
| Permission overrides | Per user, per named permission: Role default / Allow / Deny. **App-side only for now**; database rules stay role-based. User and permission management, the audit log and admin settings are never overridable. |
| Zapier / BusyBusy | On hold until BusyBusy answers what its API and Zapier actions allow (see section C). |
| Microsoft Teams / SharePoint | Possible through Microsoft Graph, but **not planned** for now. |
| Release | Version stays **0.9.0+1** until the backend is set up; signing and the release build wait for that. |
| Leaked-password protection | Owner: you. |

## A. Needs you now

| Task | Why |
|---|---|
| **Redeploy `invite-user`** | The live copy rejects the apprentice role and several divisions. The repo version is tested (27 tests). Deploy it from the dashboard (Edge Functions, `invite-user`, paste `index.ts`, `plan.ts`, `validate.ts`, `cors.ts`, Verify JWT **on**), or reconnect Supabase to the assistant and ask for a redeploy. |
| **Check the receipt disclaimer** | The five liability clauses were typed from a photo of the paper form. Compare them with the original before anyone signs (every signature is given against this text). Also confirm the disclaimer seed landed: `select version, published_at from fleet_disclaimers;` should return version 1. The depot seed is confirmed ("Brooklyn Yard"). |
| **Leaked-password protection** | Turn it on in Supabase Auth, and rotate the two passwords that appeared in an earlier chat. |
| **Cron functions** | Set the `CRON_SECRET` secret and the `SMTP_*` secrets (the digest needs them). Run `retention-cleanup` as a **dry run** first: by default it deletes every completed maintenance job (and its files) older than the retention policy. Then schedule both using the SQL in `supabase/functions/README.md`. Nothing is scheduled today. |
| **Invite emails** | In Supabase Auth, allow the redirect address (URL Configuration) and set up custom SMTP (the built-in sender is heavily limited). Invited people must open the emailed link and set a password. |
| **Add your users** | After `invite-user` is redeployed (or via Admin > Technicians > Add member for people who have signed in once). Create the divisions first. |

## B. SQL state

All files below have been run and verified unless noted.

| File | What it does | State |
|---|---|---|
| `20261110100000` to `20261110130000` | Inspection delete policy, part images, housekeeping policies and indexes, two follow-up indexes | applied and verified |
| `20261111100000_po_numbers.sql` | Server-assigned purchase order numbers (`PO-0001`); new orders show "Number pending" until they sync | applied |
| `20261111110000_approve_profile_change.sql` | Approving a generator profile change in one server step | applied |
| `20261111120000_stale_write_guard.sql` | Older edits to six tables are skipped instead of overwriting newer ones (2-minute grace) | applied |
| `20261112100000_audit_log.sql`, `20261112110000_job_costs.sql` | Admin-only audit log with triggers; job parts-cost functions | applied |
| `20261113100000_apprentice_role.sql`, `20261113110000_divisions.sql` | The `apprentice` role value; divisions table and `division_id` on members | applied and verified |
| `20261114100000_member_permission_overrides.sql`, `20261114110000_member_divisions.sql` | Per-user permission overrides; several divisions per user | applied (tables confirmed) |
| `20260825200000_vehicle_asset_checks.sql` | Fleet depots, disclaimers, signed asset receipts and lines, work order links | applied (tables confirmed); seeds run (depot confirmed) |

Edge Functions: `invite-user` (needs redeploy, see A), `retention-cleanup` and `daily-digest` are deployed (dry-run by default, return 401 without credentials). The deployed copies are comment-stripped and import shared code from `./_shared/`; the repo files are authoritative. A command-line deploy would realign them.

## C. Your other tasks

- **Stock and pricing data.** All imported parts show 0 on hand. Enter opening counts, minimums, vendors and prices.
- **Unimported spreadsheet data.** You are working on it. Three generators (Q313, Q680, Q419) have no make, model or serial, so they have no parts list yet. Ask for an import when the data is ready.
- **Part descriptions.** Replace the generic names (or run the cleanup action first).
- **BusyBusy.** Ask: is there a public API with write access? Which Zapier triggers and actions exist? Which plan is needed? Then decide which data flows each way.
- **Technician sign-in for testing.** Fill in the technician entries in `dev_credentials.local.json` (git-ignored), and add an apprentice entry to test the sign-off limits.

## D. Test on the tablet (never run on real data)

- **Server rules:** create a purchase order (number should change from "Number pending" to `PO-####` after sync), approve a generator profile change, edit the same record from two devices (stale-write guard), check the audit log page after a few changes, and view job cost on Job Needs.
- **New screens:** fleet asset receipt end to end (header, scroll-to-end disclaimer, driver signature, dispatch counter-signature, missing tool alert, PDF); Permissions screen; Divisions manager and multi-select; apprentice limits (no signature pads, no completing or deleting).
- **Earlier unviewed screens:** Orders, Locations and transfers, Movements and usage report, Parts approvals, schedule Day / Week, equipment two-pane, Documents hub, signature pads in dark mode.
- **Vehicle inspections:** save one real vehicle inspection to prove the upload end to end.
- **First run after the merge:** the app now asks for camera, photo and location permissions.

## E. Features not started

1. **Compliance calendar**: weekly, monthly and annual recurring checks for emergency generators with reminders. Confirm intervals against NFPA 110 and your contracts first.
2. **Run-hour or date maintenance triggers.**
3. **Remote monitoring**: needs controller data and hardware; not recommended unless customers ask.
4. **BusyBusy integration**: blocked on section C.
5. **Push notifications** for missing tools (the app has only in-app alerts today).
6. **Job cost in reports**: shown on Job Needs for admins; not yet on inspection or maintenance detail pages or in PDFs.
7. **Division labels** next to technician names in schedule assignment.
8. **Daily digest opt-out:** a column and a Settings switch (the code already honours `daily_digest_opt_out` if added).

Done since the last update: Generator Fleet Readiness, analytics graphs, brand theme and logos, versioning, PDF footer, server-assigned PO numbers, atomic profile approval, stale-write guard, audit log, job cost on Job Needs, invite by email (function and Admin screen), retention cleanup and daily digest (deployed, dry-run), apprentice role, divisions, permission overrides, fleet phase 4 (signed asset receipts, site check-in, device permissions).

## F. Known gaps in what is built

| Area | Gap |
|---|---|
| Permissions | Overrides and the apprentice limits are **app-side only**. An Allow on something the database refuses for that role (for example manage inventory for a technician) shows the buttons and the write fails. Fleet override also changes whether a user sees all vehicles or only their own. |
| Stale-write guard | Skips a stale update silently. A device clock more than 2 minutes off can still lose edits. Not yet checked live that a skipped upsert returns success to the app's queue. |
| Truck stock | "Own truck first" is enforced in the app only. |
| Mark used | Removing an item already marked used does not reverse its stock; changing the quantity afterwards does not update the ledger; work orders have no Mark used. |
| Purchase orders | No adding a line after creation; share is text only, no PDF. A receive done before the order syncs stores the provisional `NEW-xxxx` number in the stock note. |
| Profile approvals | Approving now needs a connection ("Connect to approve"); rejecting still works offline. |
| Retention cleanup | Report PDFs are only cleaned while there is a single company (paths carry no company). The app has no "archive" step, so completed jobs count as archived. |
| Daily digest | Inspections "next due" is estimated as last inspection plus 365 days (the app does not store a due date). No per-user opt-out yet. |
| Vehicle inspections | A second device sees the record but its signature and photo file paths point at the first device's files. |
| Fleet receipts | Disclaimer wording unverified (see A). `pod install` has never run for iOS. Play Store Data Safety needs a location entry. |
| Admin overview | Shows 29 inspections (records) while lists and Analytics show 25 (one per site). Consider relabelling. |
| Login | Dev sign-in code in `auth_controller.dart` is gated only by the build flag. |
| Settings | Keeps an "Advanced" group outside the five planned groups. |
| Android app name | The label under the icon reads "voltcore"; probably should read "Volt Core". |
| Generator Fleet Readiness | Load-test dates are inferred from inspections with the load bank switch on; borough only for `Q_` and `X_` site codes; saved filter presets not built; filters remembered for the session only. |
| Documents / inspections history | Not paged; the Documents hub and inspections lists load everything. |
| Screenshots | `docs/images/app/` still shows customer site addresses on a few screens (names, emails, phones and plates are covered). |

## G. Security and performance review (Supabase advisors, 2026-11-10)

**Security**
- *Leaked password protection disabled*: yours (see A).
- *14 functions marked "SECURITY DEFINER" that signed-in users can call*: mostly the policy helpers, which is intended. Candidates to review for removal of `EXECUTE`: `admin_lookup_user_by_email`, `get_tech_dashboard_stats`, `publish_form_template_revision`, `save_form_template_draft`, `storage_job_id`, `storage_tenant_id`. Check each against the app first.
- *`inspections_update` allows any tenant member to update any inspection*, and there are two overlapping insert policies. Worth tightening; it affects every role's editing.
- New tables added since (audit log, divisions, overrides, receipts) have not been through the advisors. Run them once.

**Performance**
- *Fixed:* four policies re-evaluating `auth.uid()` per row, a duplicate select policy, and 17 unindexed foreign keys on the tables we added.
- *Left alone:* about 40 more unindexed foreign keys, 148 "multiple permissive policies" warnings on older tables, and 65 unused indexes (drop only after real usage data exists).
- `profile_change_requests` still has two UPDATE policies (review and withdraw).

## H. Housekeeping

- **CI** is pinned to Flutter 3.47.2 (CI had picked up stable 3.50.0, which deprecates `material.dart` and failed analyze on about 300 untouched files). Moving to 3.50 later means switching imports to `package:material_ui` across the project and bumping the pin.
- **Older tables:** see [database_tables.md](database_tables.md). Four unused tables are safe to drop before real users (take a backup first); `technicians` and `role_assignments` stay until the admin code stops reading them.
- Not committed on purpose: `.mcp.json` (your change) and `assets/Shop Steward Procurement Tracker.xlsx` (business data).
- Everything else is on GitHub (`main`). PR #78 (fleet phase 4) is merged.
