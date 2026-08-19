# Voltcore — Codebase Audit & UI/UX Redesign Plan

**Date:** 2026-08-19
**Audited revision:** `03f1cc0` (origin/main, after PR #15)
**Scope:** Whole Flutter app (`lib/`, 226 Dart files, ~40,500 LOC), Supabase schema, tests, CI
**Status:** Plan only — no code changes have been made for any item below.

---

## 1. Executive summary

The app is structurally sound: clean-architecture module layout, an offline-first
sync engine with a durable outbox, RBAC scaffolding, and a themed Material 3 UI.
Recent work fixed the save pipeline (web file storage, Hive adapter registration,
missing SQL tables, tenant/session wiring), and the analyzer is at **0 errors,
1 warning, 51 infos**.

What remains falls into three buckets:

| Bucket | Headline finding |
| --- | --- |
| **Security** | The login screen lets the user pick their own role, and that choice *overrides* the server's role. All client-side RBAC is therefore advisory. |
| **Functional gaps** | Two features look finished but aren't wired to data: **Schedule never syncs to Supabase**, and **Equipment Search runs on hardcoded dummy records**. |
| **UI/UX** | Nearly every screen renders **two stacked app bars** (shell + page), five screens carry **two drawers**, and the shared component kit (`EmptyState`, `LoadingIndicator`, form fields) consists of **empty files**, so every page reinvents its states. |

Nothing here blocks the app from running; the P0 items are about trust
boundaries and the P1 items about features that appear to work but silently
don't. The recommended order is Security → Data correctness → UI/UX → Quality.

### Audit metrics

| Metric | Value |
| --- | --- |
| Dart files / LOC | 226 / 40,457 |
| Analyzer | 0 errors, 1 warning, 51 infos |
| Zero-byte stub files | 26 |
| Test files / LOC | 5 / 178 |
| TODO/FIXME markers | 5 |
| Pages defining their own `AppBar` | 29 |
| Routes wrapped in a shell that also draws an `AppBar` | 24 |
| Hardcoded colors bypassing the theme | 256 references |
| `Semantics` / `semanticLabel` usages | 0 |

---

## 2. P0 — Security & authorization

### 2.1 Client-chosen role overrides the server role

`lib/modules/auth/external/datasources/auth_remote_datasource.dart:61`

```dart
final effectiveRole = preferredRole ?? remoteRole ?? UserRole.tech;
```

`preferredRole` is the value from the login screen's role dropdown, which
**defaults to `UserRole.admin`** (`login_page.dart:24`). It takes precedence over
`remoteRole` read from `app_metadata`. Any user with valid credentials can sign in
as "Admin" and the entire client treats them as one: admin drawer entries, the
technician-role editor, admin dashboards.

Supabase RLS is the real backstop (the database still rejects unauthorized
writes), so this is a **UI-trust** flaw rather than direct data exposure — but it
also means the UI shows actions that will fail confusingly, and it exposes admin
screens to every user.

**Fix:** invert the precedence — `remoteRole ?? UserRole.tech` — and source the
role from the database rather than `app_metadata` alone: read `tenant_members.role`
for the active tenant at login (the join already exists in
`tenants_remote_datasource.dart`). Reduce the login dropdown to a *hint* used only
when the server returns multiple roles, or remove it and add a role switcher that
only offers roles the user actually holds.

### 2.2 RBAC is default-allow, and six routes have no entry

`lib/app/route_roles.dart:143-146` returns `true` when a route name is absent
from the map. These route names have no entry and are therefore open to every
signed-in role:

| Route name | Path | Risk |
| --- | --- | --- |
| `admin_technicians` | `/admin/technicians` | **Technician-role editor open to all roles** |
| `tenants_settings` | `/tenants` | Tenant configuration |
| `schedule_task` | `/schedule/task` | Low |
| `debug_menu` | `/debug` | Debug surface (debug builds only) |
| `hive_debug` | `/debug/hive` | **Raw local-database browser** (debug builds only) |
| `network_debug` | `/debug/network` | **Request log** (debug builds only) |

**Fix:** flip the default to deny (unknown route ⇒ only allow if explicitly
listed, with `login`/`forbidden` whitelisted), add the six missing entries, and
add a test that fails when a `RouteNames` constant has no `RouteRoles` entry.

### 2.3 Debug pages are reachable by any role in debug builds

`/debug`, `/debug/hive`, `/debug/network` expose the raw local database and the
request log.

**Correction to an earlier draft of this audit:** these routes are *already*
excluded from release builds — `app_router.dart:322` wraps them in
`if (kDebugMode)`. The real gap was §2.2 only: with no `RouteRoles` entry they
were open to every role in debug/internal builds.

**Fix:** covered by the §2.2 entries (`debug_menu`, `hive_debug`,
`network_debug` → admin only). No change to release-build behaviour is needed.

---

## 3. P1 — Functional gaps

### 3.1 Schedule never syncs to Supabase

`ScheduleRemoteDatasourceImpl` and `scheduleRemoteDatasourceProvider`
(`schedule/external/datasources/schedule_remote_datasource.dart`) are defined but
**never referenced anywhere**. `ScheduleRepositoryImpl` is Hive-only
(`schedule_repository_impl.dart:14`, `:86`) and enqueues no sync operation.

Consequences: scheduled tasks exist only on the device that created them; the
`schedule_tasks` table added in migration `0003` receives no rows; the dashboard's
"Total tasks" can never reflect work created elsewhere.

**Fix:** route `ScheduleRepositoryImpl.save/delete` through
`SyncService.enqueueUpsert/enqueueDelete` (mirroring
`inspection_repository_impl.dart`), and hydrate from
`ScheduleRemoteDatasource.list()` on schedule-page load, merging remote rows into
Hive by id. Stamp `tenant_id` from `SyncContext`.

### 3.2 Equipment Search is a mock

`lib/providers/equipment_providers.dart:147` — `equipmentListProvider` returns a
hardcoded list ("Generator Unit A1", Caterpillar C32, …) after a simulated 500 ms
delay, marked `TODO: Implement actual data fetching`. The page above it is 940
lines of finished UI, and its "Inspect" action navigates to `/nameplate/${id}`
with ids `'1'`, `'2'`, `'3'` — which resolve to nothing.

Nine of the ten files in `modules/equipment/` are zero bytes (entity, model,
repository, both datasources, usecase, controller, tile).

**Fix (choose one):**
- **Implement:** derive equipment from existing `nameplates` + `inspections` Hive
  data (the domain data already exists), then add a Supabase-backed
  `equipment` table later; or
- **Hide:** remove the drawer entry and route until implemented, so users aren't
  shown fake inventory.

Recommendation: **hide first** (one-line drawer change), implement in a dedicated
follow-up — showing fabricated equipment records in a compliance tool is worse
than showing nothing.

### 3.3 Nameplate save writes under two different key types

`inspection_local_datasource.dart:99` saves new nameplates with `box.add(model)`
(auto-integer key), while `nameplate_intervals_page.dart:316` writes the same
records with `HiveBoxes.nameplates.put(curr.id, curr)` (string key). The same
logical nameplate can therefore exist under two keys, and updates through one
path won't be visible to the other.

This is the same class of bug already fixed for inspections in `8c9f4df`.

**Fix:** use `box.put(model.id, model)` in `saveNameplate`, plus a one-time
migration that rewrites integer-keyed entries to their string ids.

### 3.4 Settings module's clean-arch layer is hollow

8 of 14 files under `modules/settings/` are zero bytes (entity, model, both
repositories, both usecases, local datasource, controller). The Settings page
works, but against `selection_options_service.dart` directly — so the empty layer
is misleading scaffolding that suggests wiring that doesn't exist.

**Fix:** delete the empty files (preferred — the service is adequate), or
implement the layer. Do not leave them as-is.

### 3.5 Tenant name in the drawer is a hardcoded placeholder

`app_shells.dart:125` — `const tenantName = 'Default Site';`, despite
`TenantsService` + the (now working) `tenant_members` join populating real tenant
names at login.

**Fix:** read tenants from `tenantsServiceProvider`, show the active one, and wire
the drawer's tenant switcher to it.

### 3.6 No unsaved-work protection on long forms

No `PopScope` / `WillPopScope` and no autosave anywhere in the codebase. The
inspection form holds 9 sections and ~25 fields; navigating back, tapping a
drawer entry, or a browser back-gesture discards everything silently.

**Fix:** `PopScope` confirm-on-dirty for both form pages, plus a debounced draft
write to Hive (drafts already have ids) and "Resume draft?" on re-entry.

---

## 4. UI/UX audit

### 4.1 Double app bar on nearly every screen — highest-impact defect

Confirmed visually: the Inspection Detail screen shows **"Voltcore — Technician"**
and, directly beneath it, **"← Inspection Detail"**.

Cause: `DefaultShell` (which `TechShell` and `AdminShell` both delegate to) always
builds a `Scaffold` + `AppBar` (`app_shells.dart:37-53`), and **29 pages** build
their own `Scaffold` + `AppBar` inside it. `ResponsiveScaffold` doesn't help —
it's a plain `Scaffold` that renders whatever `appBar` the page passes.

Cost: ~112 dp of vertical space on phones, duplicated/competing titles,
two back-affordances, and a hamburger that appears next to a back arrow.

### 4.2 Five screens carry two drawers

`maintenance_archive_page`, `maintenance_detail_page`, `inspection_form_page`,
`analytics_page`, `document_library_page` each set `drawer: AppDrawer()` while
already inside a shell that provides one.

### 4.3 Shared component kit is empty files

`shared/widgets/empty_state.dart`, `loading_indicator.dart`,
`form_fields/labeled_field.dart`, `form_fields/selection_field.dart` — all **0
bytes**. Consequences: 22 files hand-roll `CircularProgressIndicator`, and empty
states are re-implemented per page (`_EmptyState` in `technicians_page.dart:298`,
`_buildEmptyState` in three schedule widgets, inline `Text('No intervals yet…')`
elsewhere) with different copy, icons, and spacing. Several list screens have no
empty state at all.

### 4.4 Shells are cosmetic; navigation isn't role-aware

`TechShell` and `AdminShell` differ from `DefaultShell` only by title string
(`app_shells.dart:74-109`). A technician and an admin get the same navigation
surface, with RBAC only refusing at the destination (→ `/403`), which reads as a
dead end rather than a scoped app.

### 4.5 Long unstructured form

The inspection form is one continuous scroll of 9 sections with no step
indicator, no section navigation, no progress, and no validation summary — the
first invalid field is reported by a generic "Please fill in all required fields"
snackbar with no scroll-to-error.

### 4.6 Field ergonomics and accessibility

- **0** `Semantics` / `semanticLabel` usages in the entire app; screen readers get
  icon-button labels only where a `tooltip` happens to exist (38 instances).
- Only **1** explicit tap-target sizing constraint. Default `IconButton`s are
  fine, but chips/rows in dense lists aren't verified against the 48 dp minimum —
  this is a gloves-and-daylight field tool.
- **256** hardcoded color references outside `core/theme` / `core/constants`,
  which will fight dark mode and any future rebrand.
- `surfaceVariant` (deprecated) still used in 8 places.

### 4.7 Two dashboards, with a routing mismatch

`/` (`DashboardPage`) and `/tech-dashboard` (`TechDashboardPage`) both exist.

**Correction to an earlier draft of this audit:** `/tech-dashboard` is *not*
orphaned. `DashboardPage` offers a "My Workload" tile pointing at it
(`dashboard_page.dart:799`), visible to all four roles — the `routing_audit.md`
note predates that tile. The actual defect was an RBAC mismatch: the route was
restricted to technicians, so every other role hit `/403` from a tile they were
shown. Fixed in §6.3e. `TechDashboardPage` remains the only consumer of the
`get_tech_dashboard_stats` RPC from migration `0003`.

---

## 5. P2 — Code quality

| Item | Detail | Action |
| --- | --- | --- |
| Analyzer: `deprecated_member_use` ×36 | `Radio.value/groupValue/onChanged` ×26, `surfaceVariant` ×8, `anonKey` ×2 | Migrate to `RadioGroup`, `surfaceContainerHighest`, `publishableKey` |
| Analyzer: `use_build_context_synchronously` ×7 | `inspection_form_page` ×4, plus debug/nameplate/maintenance list | Guard with `mounted` after every `await` |
| Analyzer: `unintended_html_in_doc_comment` ×6 | Generic types in `///` comments | Wrap in backticks |
| Analyzer: `unused_field` ×1 | `_uuidKeys`, `sync_service.dart:272` | Remove |
| Test coverage | 5 files / 178 LOC against ~40,500 LOC; no widget or repository tests | Add form-save, RBAC-map, and repository/sync tests |
| README | Still the default `flutter create` template | Replace with real setup + env/Supabase bootstrap steps |
| Zero-byte files | 26 across equipment/settings/shared | Implement or delete (§3.2, §3.4, §4.3) |

---

## 6. Implementation plan

Ordered so each phase is independently shippable and verifiable.

### Phase 1 — Security (P0) · ~0.5 day · ✅ IMPLEMENTED

> Delivered. `auth_remote_datasource` now reads grants from `tenant_members`
> (active rows only, scoped to `SUPABASE_TENANT_ID` when set) and treats the
> login selector as a hint that is honoured only if the user holds that role;
> `restoreSession` validates the locally stored role the same way;
> `AuthController.switchRole` refuses ungranted roles; `RouteRoles` is
> default-deny with all previously missing entries added. 18 new tests
> (`test/app/route_roles_test.dart`, `test/auth/role_resolution_test.dart`).
>
> **Operational note:** roles now come from the database. A user with no active
> `tenant_members` row (or whose row is under a different tenant than
> `SUPABASE_TENANT_ID`) is treated as `tech`, regardless of what they pick at
> login. Grant admin explicitly:
> ```sql
> insert into public.tenant_members(tenant_id, user_id, role)
> values ('<SUPABASE_TENANT_ID>', '<auth user uuid>', 'admin')
> on conflict (tenant_id, user_id) do update set role='admin', is_active=true;
> ```

1. Invert role precedence in `auth_remote_datasource.dart`; source role from
   `tenant_members.role`.
2. Reduce/remove the login role dropdown; add a role switcher limited to held roles.
3. Flip `RouteRoles` to default-deny; add the 6 missing route entries.
4. ~~Register debug routes only under `kDebugMode`~~ — already the case
   (`app_router.dart:322`); the admin-only entries from step 3 cover the gap.
5. Add a test asserting every `RouteNames` constant has a `RouteRoles` entry.

**Acceptance:** a `tech` account cannot reach `/admin/technicians`, `/tenants`, or
`/debug/*`; signing in with the dropdown set to Admin yields the server's role.

### Phase 2 — Data correctness (P1) · ~1–1.5 days · ✅ IMPLEMENTED

> Delivered. `ScheduleRepositoryImpl` now enqueues upserts/deletes through
> `SyncService` and hydrates from `ScheduleRemoteDatasource` on load (local wins
> on conflict, so queued edits aren't clobbered); the schedule dialog was
> converted to a `ConsumerStatefulWidget` and routed through the repository so
> there is a single write path. `saveNameplate` keys by string id, with a
> startup `HiveMigrations` pass that re-keys legacy integer-keyed rows and drops
> duplicates. Equipment Search is hidden behind
> `FeatureFlags.equipmentSearchEnabled` (route + drawer). The 8 empty settings
> files are deleted. The drawer shows the real tenant from `TenantsService`
> (and omits the row when none is known, instead of "Default Site").
>
> Also hardened along the way: `SyncContext.tenantId` no longer throws when
> dotenv is uninitialised — it degrades to "no tenant", so a missing `.env`
> can't take down every serializer.

1. Wire `ScheduleRepositoryImpl` through `SyncService` (upsert + delete) and
   hydrate from `ScheduleRemoteDatasource.list()` on load.
2. Fix `saveNameplate` to `put(model.id, …)`; add the key-migration pass.
3. Hide Equipment Search behind a feature flag (drawer + route) pending real data.
4. Delete the empty `settings/` clean-arch files.
5. Wire the drawer's tenant display/switcher to `TenantsService`.

**Acceptance:** a task created on web appears in `schedule_tasks` in Supabase and
on a second device; nameplates survive edit round-trips under one key; no
fabricated equipment is reachable from the UI.

### Phase 3 — UI/UX redesign · ~2–3 days

> **3a and 3b delivered.** The shell now renders *no* AppBar: it publishes
> navigation through an `AppShellScope` (drawer on compact, rail on wide) and
> `AppPage` builds the single `Scaffold` + `AppBar`, appending the sync
> indicator automatically. All 26 routed pages were converted, the 5 nested
> `AppDrawer`s removed, and `ResponsiveScaffold` deleted. The kit
> (`EmptyState` with error/offline variants, `LoadingIndicator` with
> inline/button variants, `LabeledField`, `SelectionField`, `SectionCard` +
> `SectionHeader`) is implemented behind one barrel import
> (`shared/widgets/widgets.dart`); page-level spinners and the bespoke empty
> states in technicians/documents/archive now use it. 17 new widget tests.
>
> Also removed en route: a hardcoded fake user profile ("Field Tech",
> `tech@aselectricnyc.com`) that `maintenance_list_page` was passing to the
> old scaffold.
>
> Still open from 3b: `LabeledField`/`SelectionField` exist and are tested but
> the form sections have not been migrated onto them yet — that lands with the
> form work in 3d.

**3a. Unify page chrome (the double-app-bar fix).**
Introduce a single contract so the shell owns the chrome:

```dart
// shared/widgets/app_page.dart
class AppPage extends StatelessWidget {
  const AppPage({
    required this.title,        // rendered by the shell's AppBar
    required this.body,
    this.actions = const [],
    this.fab,
    this.showBack = false,
  });
}
```

- `DefaultShell` renders exactly one `AppBar`, taking title/actions from the
  current `AppPage` (via an `InheritedWidget` or a small Riverpod
  `pageChromeProvider`).
- Convert the 29 pages: delete their `Scaffold`/`AppBar`, return `AppPage`.
- Remove `drawer:` from the 5 offending pages.
- Retire `ResponsiveScaffold` once its 5 call sites are converted.

**3b. Build the shared component kit** (fills the empty files):
`EmptyState` (icon + title + body + optional action), `LoadingIndicator`
(consistent sizing/centering), `LabeledField`, `SelectionField`, `AppCard`,
`SectionHeader`. Then replace the 22 ad-hoc spinners and 6+ bespoke empty states.

> **3c and 3d delivered.** Drawer filtering now fails closed (no role or no
> `routeName` ⇒ hidden) and a new admin-only "Administration" section adds the
> two screens that had *no* navigation entry at all — `/admin/technicians` and
> `/tenants` were reachable only by typing a URL. A role switcher appears in the
> profile footer only for accounts holding more than one server-granted role,
> routed through the validated `switchRole`. The inspection form gained
> debounced draft autosave (`FormDraftService`) with a restore prompt, a
> `PopScope` discard guard, a section jump sheet flagging sections with missing
> required fields, scroll-to-section on validation failure, and a named
> validation message; the maintenance form gained the discard guard. 27 new
> tests.
>
> Found while testing: the Hive `Inspection` model has no `updatedAt` column
> (`toEntity()` substitutes `DateTime.now()`), so draft-vs-saved comparison by
> `updatedAt` was meaningless. Draft write times are now stored separately.
>
> Still open from 3d: `LabeledField`/`SelectionField` adoption inside the form
> sections, and per-section error badges beyond the site-info required fields.

**3c. Role-aware navigation.** Filter drawer items through `RouteRoles` for the
current role so users only see what they can open; keep `/403` as a backstop, not
the primary experience. Give `TechShell`/`AdminShell` real differences (tech:
Inspections / Maintenance / Schedule / Documents; admin adds Analytics /
Technicians / Tenants / Settings) or collapse them into one shell.

**3d. Form experience.**
- Section navigation: sticky section header + jump list (or a `Stepper` on
  narrow screens) driven by the existing 9 section widgets.
- `PopScope` unsaved-changes guard + debounced Hive draft autosave + resume prompt.
- Validation summary: scroll to and focus the first invalid field; per-section
  error badges instead of a single generic snackbar.
- Persistent bottom **Save** bar on mobile (thumb reach) with explicit
  saving/queued/failed state fed by `SyncStatus`.

**3e. Resolve the dashboard duplication.** ✅ **Done — kept both, fixed the
mismatch.** `/tech-dashboard` is not orphaned after all: `DashboardPage` offers a
"My Workload" tile to all four roles, but `RouteRoles` restricted the route to
technicians, so everyone else landed on `/403`. Per the owner's decision the
route now accepts all roles — personal workload stats are meaningful for each —
which also keeps the `get_tech_dashboard_stats` RPC from migration 0003 in use.
The earlier "orphaned page" reading in `docs/routing_audit.md` predates that tile.

**3f. Ergonomics & a11y pass.** ✅ **Done, except the colour sweep.** Signature
pads grew 180→220 dp and their Clear buttons went from ~26 dp to the 48 dp
minimum; the drawer's tenant-switch button had its constraints zeroed (~20 dp
target) and now honours `kMinInteractiveDimension`. `Semantics` reached the app
for the first time: the sync chip announces its state and action, photo
thumbnails announce their caption, signature pads are labelled, `EmptyState`
merges into one announcement with its icon excluded, `LoadingIndicator` has a
spoken label, and `SectionHeader` is a real heading node. Six tests cover this,
including Flutter's own `androidTapTargetGuideline` / `iOSTapTargetGuideline`.

Fixed while testing: `SectionHeader`'s `header: true` had no `container: true`,
so the flag merged upward and marked the *entire card* — fields included — as a
heading.

Still open: replacing the 256 hardcoded colours with `ColorScheme` tokens, which
stays batched with the deprecation sweep in Phase 4.

**Acceptance:** every screen shows exactly one app bar and one drawer; all list
screens use `EmptyState`/`LoadingIndicator`; a dirty form prompts before
discarding; a technician's drawer contains no admin entries.

### Phase 4 — Quality · ~0.5–1 day

1. Clear the 51 analyzer infos (Radio migration, `surfaceContainerHighest`,
   `publishableKey`, `mounted` guards, doc-comment backticks, `_uuidKeys`).
2. Tests: inspection save→reload round-trip; RBAC map completeness; schedule
   sync enqueue; `WebFileStore` put/get; form validation.
3. Rewrite `README.md`: architecture, env setup, Supabase bootstrap, run/build.
4. Extend CI to run `flutter analyze --fatal-infos` once clean.

---

## 7. Supabase configuration (carried over, not code)

These remain environment tasks and are unchanged by this plan:

1. Run `supabase/migrations/0003_missing_tables.sql` in the active project.
2. Ensure a `tenants` row exists whose id matches `SUPABASE_TENANT_ID`, plus a
   matching `tenant_members` row for each user (`role in ('admin','supervisor','dispatcher')`
   for write access under the v2 policies).
3. `SUPABASE_TENANT_ID` must be a **tenant** id, not a user id, and lives in
   `assets/env/.env.*` — it is compiled into the asset bundle, so a **rebuild** is
   required after changing it.
4. Storage bucket `voltcore-files` with an authenticated read/write policy.

Verification query:

```sql
select exists(
  select 1 from public.tenant_members
  where tenant_id = '<SUPABASE_TENANT_ID>'
    and user_id   = auth.uid()
    and is_active
) as writes_will_pass;
```

---

## 8. Out of scope / follow-ups

- Real equipment inventory backend (§3.2) — needs a schema and an import path.
- Multi-tenant switching UX beyond displaying the active tenant.
- Conflict resolution for concurrent edits (sync is currently last-write-wins via
  `client_updated_at`).
- Push notifications (only local notifications exist today).
- Making `schedule_tasks` genuinely tenant-scoped (uuid `tenant_id` + member
  policies) once the app stamps real tenant ids — noted in migration `0003`.

---

## 9. Suggested sequencing

| Order | Phase | Effort | Unblocks |
| --- | --- | --- | --- |
| 1 | Security (§6.1) | 0.5 d | Trustworthy role model |
| 2 | Data correctness (§6.2) | 1–1.5 d | Schedule actually syncing |
| 3 | UI chrome + component kit (§6.3a–b) | 1 d | Every screen's layout |
| 4 | Nav + form UX (§6.3c–e) | 1–1.5 d | Daily technician workflow |
| 5 | Ergonomics/a11y (§6.3f) + Quality (§6.4) | 1 d | Release readiness |

Total: roughly **5–6 working days** for all phases.
