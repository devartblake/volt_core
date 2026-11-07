# Volt Core — UI/UX Revamp Plan

Status: **Sprints 1-4 done and the open items closed** (updated 2026-11-08). What little remains is in section 10.

This plan comes from a static audit of the codebase. Per-screen items are hypotheses to confirm on the tablet before work starts.

## 1. Audit findings

| Area | Finding |
|---|---|
| Navigation | `lib/app/app_drawer.dart` is ~1,450 lines. 8 sections and 30+ items; Maintenance alone has 5 (All Jobs, Create Job, Schedule…). On tablets the rail is icon-only. |
| Consistency | Snackbars were mixed (~70 raw `showSnackBar` vs ~33 `AppSnackBar`). Empty states mixed `EmptyState` with ad-hoc text. `_StatCard`, `_StatusChip`, `_InfoChip` each duplicated ~5×. |
| Theming | ~134 literal `fontSize` values and many hard-coded colours (core 30, debug 22, auth 11, shared 9). Single breakpoint (900). |
| Accessibility | Only ~13 `Semantics` uses. Chip text near-invisible in places because it relied on theme defaults. |
| Oversized files | equipment_search_page (1,137), dashboard_page (1,091), schedule pages (~850), maintenance form sections (700–850), login_page (967), vehicle_inspection_form_page (814). |
| Known UX defects | Dashboard spinner hangs when network calls time out. Sync badge shows a bare count (e.g. "75"). New maintenance record is titled "Edit Maintenance Record". |

## 2. Phases

### Phase 1 — Design-system foundation (Sprint 1)

1. **Design tokens** — `AppSpacing`, `AppRadius`, `AppBreakpoints`/`WindowSize`, `AppFontSize` in `lib/core/theme/app_tokens.dart`; semantic status colours already exist in `status_colors.dart`.
2. **Type scale** — one scale in `AppTypography`; no literal `fontSize` in feature code.
3. **Shared components** (`lib/shared/widgets/`, exported from `widgets.dart`): `StatCard`, `StatusChip` / `InfoChip`, `Skeleton` / `SkeletonList`, alongside the existing `EmptyState` (incl. `.error` / `.offline`), `LoadingIndicator`, `SectionCard` / `SectionHeader`.
4. **One feedback channel** — migrate raw `showSnackBar` to `AppSnackBar`.
5. **Responsive helper** — compact < 600, medium 600–900, expanded ≥ 900.
6. **Accessibility baseline** — 48 dp targets, contrast check on status colours, `Semantics` on icon-only controls, 1.3× text-scale testing.

### Phase 2 — Navigation and information architecture

- Split `app_drawer.dart` into a data-driven nav config (sections, items, roles) kept next to `route_roles.dart`.
- Tablet: labeled rail that expands to a drawer in landscape. Phone: bottom bar (4–5 destinations) plus a "More" sheet.
- Flatten: Home, Work (inspections, maintenance, schedule, work orders), Fleet, Equipment, Documents, Admin, Settings. Merge "All Jobs / Create Job / Schedule" into one Work list with tabs and a "New" button; Inspection Log becomes a tab under Fleet.
- Global search / command palette; clear titles on deep pages.
- Role-based home: technician → "My day", dispatcher → schedule, admin → overview.

### Phase 3 — Section revamps

| Section | Changes | Priority |
|---|---|---|
| Dashboard | Split into widgets; "Today" strip with link-through stat cards; skeleton loading; cached data with "last updated"; fix hung spinner with the existing timeout/cooldown pattern; one role-adaptive dashboard. | High |
| Maintenance | Stepper with progress bar, per-step completeness, autosave drafts; fix "New" vs "Edit" title; detail page with summary header and sticky action bar (PDF, Print, Share, Sign); date/status filters from Inspections. | High |
| Inspections | Saved filter presets, status/trade filter, swipe actions, density toggle; form with sticky progress and an "unanswered" jump list. | Medium |
| Fleet | Vehicle cards with status badge; detail as tabs (Overview, Inspections, Maintenance, Media, Documents); "start daily check" shortcut; signatures and photos in vehicle PDF. | Medium |
| Schedule / Work orders | Week/day calendar, tap-to-assign, technician filter; split ~850-line pages; one job card. | Medium |
| Equipment search | Split the page; recent searches; QR/barcode entry; detail pane on tablets. | Medium |
| Documents | One hub for saved PDFs by type and date: open, print, share. | Medium |
| Settings / Admin | Group into Account, Appearance, Data & Sync, PDF, About; sync diagnostics screen. | Low–medium |
| Login | Simplify; real validation; dev sign-in only behind the debug flag. | Low |

### Phase 4 — Offline/sync UX, performance, polish

- **Sync centre**: tappable sheet listing pending items by type, failures with Retry, last successful sync time.
- Offline banner ("changes saved on this device") and per-record "pending upload" markers.
- Pagination / `ListView.builder` for long lists, cached thumbnails, `select` on providers.
- Page transitions, save/export confirmations, undo on delete.
- Dark-mode and contrast audit once tokens are in place.

## 3. Sprint order

1. **Sprint 1** — Phase 1 (tokens, shared components, snackbar migration) plus the dashboard hung-spinner fix.
2. **Sprint 2** — Phase 2 navigation refactor; dashboard revamp.
3. **Sprint 3** — Maintenance form/detail; Fleet vehicle tabs.
4. **Sprint 4** — Schedule, Equipment, Documents hub, sync centre.
5. **Ongoing** — accessibility and responsive passes; widget tests for each shared component.

## 4. Sprint 1 progress

Done:

- [x] `lib/core/theme/app_tokens.dart` — spacing, radius, breakpoints, font sizes.
- [x] `StatusChip` (+ `StatusTone`, `StatusChip.colored`) and `InfoChip` — replace private chips in inspections, maintenance, schedule and fleet list screens.
- [x] `StatCard` (regular and compact), `Skeleton`, `SkeletonList`.
- [x] 45 plain `showSnackBar` calls migrated to `AppSnackBar` (success / error / info chosen from the message).
- [x] Tests: `test/shared/phase1_components_test.dart`.

Also done:

- [x] Equipment and schedule-detail status chips now use `StatusChip`.
- [x] All remaining `showSnackBar` calls go through `AppSnackBar` (new `successOn / errorOn / warningOn / infoOn` variants for code that resolved the messenger before an `await`). `context.showSnackBarMessage` delegates to it. Only `AppSnackBar` itself calls `showSnackBar` now.
- [x] Hard-coded `Colors.blue/green/amber` replaced with theme / status colours on the schedule task page, vehicle inspection log, dashboard and asset history; fixed font sizes replaced with `TextTheme` roles on the inspection log and nameplate pages.
- [x] Accessibility: every icon-only `IconButton` now has a tooltip (19 added), which screen readers announce.

Left on purpose:

- PDF code (`core/services/pdf`, `pdf_template.dart`, template report service) keeps literal sizes and colours: ~170 of the 214 `fontSize` literals. PDFs are not themed.
- Login page keeps its fixed dark brand palette (`0xFF1a1a2e` gradient, red/blue banners tuned for it). Revisit when the login is redesigned.
- Debug pages keep raw colours (developer-only).
- Calendar timeline, drawer and sync-indicator font sizes (12–13) are widget-library or dense-layout values.
- Analytics and inspection-list stat cards need a `StatCard` variant first.

Also done (tap targets, text scale, stat cards):

- [x] **Tap-target audit.** Went through all 30 InkWell / GestureDetector uses. Cards and 84 dp photo tiles were fine. Two were under 48 dp and are fixed: the sync indicator in the app bar and the role switcher in the drawer.
- [x] **1.3x text scale.** New 	est/shared/text_scale_test.dart pumps the shared components, date filter bar, sync indicator, vehicle inspection log, daily vehicle inspection form and schedule task detail at 1.3x on a phone, tablet portrait and tablet landscape. It found and fixed three overflows: EmptyState in short spaces (now scrolls), and the day-group headers on both the vehicle inspection log and All Inspections (long dates now ellipsize). Also checked on the Samsung tablet at 1.3x (dashboard, All Inspections, Vehicle Inspection Log): no overflow. The tablet was set back to its original 1.15.
- [x] **Stat cards.** StatCard.tile covers the analytics grid; StatCard(compact: true) covers the All Inspections summary row. No private _StatCard classes remain.

Not yet covered at 1.3x: the maintenance wizard, equipment search, settings and login pages (they need heavier test setup or a manual pass on the tablet).
## 5. Sprint 2 progress: navigation

Done:

- [x] **Consolidated menu.** 31 entries in 8 groups became 21 pages in 8 sections, each section one tablet-rail destination:

  | Section | Pages |
  |---|---|
  | Home | Dashboard, Analytics |
  | Inspections | Inspections, Pending Reviews |
  | Work | Jobs, Maintenance, Schedule, Archive |
  | Fleet | Vehicles, Inspection Log, Tool Catalog |
  | Customers & Equipment | Customers & Sites, Equipment (Asset Search when enabled) |
  | Documents | Documents |
  | Settings | Settings, Configuration, About |
  | Administration | Overview, Technicians, Tenants, Admin Settings |

  "Create Inspection" and "Create Job" are no longer menu entries: both lists already have a New button, and both remain quick actions in the phone drawer. "Archived Maintenance" moved under Work as "Archive"; Directory + Equipment merged; System + About merged into Settings.
- [x] **Labelled rail.** The tablet rail shows one labelled entry per section (it was ~25 unlabeled icons).
- [x] **Section tabs.** Under each page's app bar, a chip row switches between the section's pages (`AppShellScope.sectionTabs` -> `AppPage`). Hidden on the full-width sidebar (>= 1200), which already lists every page, and on pages that supply their own bottom bar.
- [x] Role filtering is unchanged (same `RouteRoles` check; technicians never see Administration).
- [x] **Chip fix at the source.** Filter/action/choice chip labels had no colour in the theme and were near-invisible (e.g. "Due date" on Jobs, the selected tab). The theme now sets a per-state label colour; covered by `test/shared/chip_theme_test.dart` in light and dark.
- [x] Jobs summary tiles use `StatCard` (fixes "Unassigne d" wrapping); dashboard tile grid is shorter at two columns.
- [x] Tests: `test/app/section_nav_test.dart` (grouping, every page still reachable, rail size, role filtering, tabs).

Also done in Sprint 2:

- [x] **`app_drawer.dart` split** (1,456 lines) into focused files in `lib/app/`:

  | File | Holds |
  |---|---|
  | `nav_config.dart` (430) | breakpoints, `NavItem` / `NavSection`, the section list, role filtering, selection and `sectionNavFor` helpers |
  | `nav_widgets.dart` (378) | drawer sections, tiles, header, quick actions, badge icon, brand |
  | `nav_profile.dart` (450) | user profile footer, role switcher, tenant switcher, rail mini-profile |
  | `app_drawer.dart` (255) | the `AppDrawer` itself (compact drawer, rail, wide sidebar); re-exports the above so existing imports keep working |
  | `app_bottom_nav.dart` | the bottom bar |
  | `nav_style_provider.dart` | the saved rail / bottom choice for tablets |
- [x] **Phone bottom bar.** Home, Inspections, Work, Fleet and More (opens the full drawer); shown on top-level pages only, so detail and form screens keep their back arrow and own bottom bars. Fits at 1.3x text on a 360 dp phone (tested).
- [x] **Tablet bottom bar (optional).** Settings > Appearance > "Bottom navigation on tablets" swaps the side rail for a bar with every section. The default stays the rail.
- [x] Dashboard tiles: shorter on single-column (phone) widths.
- [x] Tests: `test/app/bottom_nav_test.dart`.

Also done (dashboard, search, titles):

- [x] **Role-based dashboard** (`dashboard_page.dart` rewritten; 1,091 lines -> ~560, plus `domain/dashboard_summary.dart` and `widgets/dashboard_sections.dart`). One screen that changes with the role:

  | Role | Headline | Stat tiles | Flagged as needing attention |
  |---|---|---|---|
  | Technician | Your day | Today, Overdue, My open jobs, Daily check | overdue tasks, own daily vehicle check, overdue jobs |
  | Dispatcher | Dispatch | Today, Overdue, Open jobs, Unassigned | + unassigned jobs |
  | Supervisor | Review | Today, Overdue, Red-grade sites, Inspections (7 days) | + red-grade sites |
  | Admin | Overview | Today, Overdue, Open jobs, Inspections (7 days) | everything above |

  Also: a "Today" list in time order (tap opens the task), quick-action tiles per role (filtered by `RouteRoles`), a search bar, skeleton loading, a load-error banner with Retry (the page still shows saved data), pull-to-refresh, "Updated 3:47 PM", and an "All clear" state.
- [x] **Counts fixed.** The old dashboard called every past task "overdue" and every past task "completed", whatever its status. Overdue now means dated before today and still open; cancelled tasks are ignored; tests cover each rule.
- [x] **Global search** (`modules/search/`). Search button in every page's app bar (and a search bar on the dashboard) opens a full-screen search over menu pages, inspections, maintenance records, jobs, vehicles and customers/sites. Multi-word, case-insensitive, ranked (title starts-with first, pages above records), grouped by type. Each source is role-gated with the same `RouteRoles` rules as the menu and skipped if it fails to load.
- [x] **Page titles match the tabs:** Jobs, Maintenance, Archive, Vehicles, Inspection Log, Equipment, Asset Search, Technicians, Configuration, Admin Overview.
- [x] Tests: `test/dashboard/dashboard_test.dart` (summary rules, per-role attention, widgets at 1.3x on phone and tablet), `test/search/search_index_test.dart`.

Finished later (2026-11-07):

- [x] Search covers equipment (name, make, model, serial, site) and schedule tasks, and parts (see `materials_and_inventory_design.md`). It is a bottom sheet, with recent searches (last 8) and Ctrl+K / Cmd+K from anywhere in the app shell.
- [x] Dashboard: "Who is on what today" for dispatchers and admins (tasks per technician, next task time, Unassigned row).

Finished in Sprint 4 (2026-11-08):

- [x] Dashboard: a 7-day sparkline on the "Inspections, 7 days" tile (supervisor and admin), with a spoken description.
- [x] "Who is on what today" rows open the schedule on that technician (`/schedule?technician=<id|unassigned>`).
- [x] Dashboard Needs attention gains "Parts short for N jobs" (dispatcher, supervisor, admin).

## 6. Sprint 3: Maintenance and Fleet

Done:

- [x] **Maintenance form** (`maintenance_form_page.dart`):
  - Each of the 8 steps has a real status (Not started / In progress / Done), worked out by `domain/maintenance_progress.dart`. "Done" means the step's key details are present; nothing blocks saving. Site Information and Signatures are the two expected steps; Parts and Photos are optional.
  - A header shows the current step, its status, an overall progress bar ("3 of 8 done") and "Draft saved 3:21 PM".
  - Phone: a scrollable strip of steps with status icons, tap to jump. Tablet: the left list shows each section's status.
  - One sticky Previous / Next / Complete & Save bar replaces the floating button plus a second set of buttons under the form. At large text the labels shrink instead of overflowing.
  - **Autosave drafts.** Edits are written to the device 1.5 s after typing stops, when moving between steps, when the app is backgrounded and when the form closes, so a half-finished record survives the app being killed. Drafts skip the cloud sync queue; the final save queues it.
  - Backing out of a brand-new record nobody typed into now deletes it (it used to leave a blank record in the list).
  - Finishing with Site Information or Signatures empty lists them in a dialog and lets you "Save anyway". Finishing with both filled in marks the record completed (follow-up flag preserved).
  - The title was already "New" vs "Edit" correctly.
- [x] **Maintenance detail** (`maintenance_detail_page.dart`): a summary header with status (Completed / In progress), follow-up and signature chips, date, technician, generator and a progress bar; a sticky Continue-or-Edit / Print / PDF bar replaces four app-bar icons (Delete stays in the menu); the record's photos now show on the page. Records signed off before this change count as Completed.
- [x] **Vehicle detail** (`vehicle_detail_page.dart`): one long scroll became five tabs (Overview, Inspections, Maintenance, Media, Tools) with counts on the list tabs, under a summary strip (status, assigned, daily check done / due with a Start button, plate, make, mileage).
- [x] **Section tabs only on a section's own pages.** Detail and form screens no longer show the Jobs / Maintenance / Schedule / Archive row.
- [x] Tests: `maintenance_progress_test.dart`, `maintenance_form_page_test.dart` (steps, jumps, finish dialog, drafts, 1.3x chrome), `vehicle_detail_tabs_test.dart`.

Finished later (2026-11-07):

- [x] **Maintenance list:** In progress / Completed chips, an All / In progress / Completed filter (`domain/maintenance_list_filter.dart`), swipe left to delete with Undo.
- [x] **Inline validation:** "Required to finish" on Site Information key fields and both signature names, shown after leaving a step or pressing Complete & Save (`domain/maintenance_validation.dart`). Saving is never blocked.
- [x] **Vehicle Documents tab** listing the vehicle's saved PDFs (matched by the 8-character vehicle id in the file name, so PDFs saved under an older naming do not appear).
- [x] **Vehicle PDF** now carries the latest inspection's signatures and the vehicle and inspection photos, inside the branded-footer layout.
- [x] **Fleet list cards** show the status chip and a "Daily check: done today / due / overdue" chip (`fleet/domain/daily_check_status.dart`, shared with the vehicle page).

Known gaps: the maintenance "In progress" chip shows no step count (the list lacks photo and material counts); opening and sharing from the vehicle Documents tab is not covered by tests.

## 7. Open housekeeping (unrelated to UI)

- Enable leaked-password protection in Supabase.
- Rotate the two passwords that appeared in chat.
- Intermittent `pdf_export_test` race (temp dir removed during background write).
- The Signatures section builds a `ListTile` inside a coloured box, which Flutter flags in debug (ink effects hidden).

## 8. Sprint 4: Schedule, Equipment, Documents, Sync (2026-11-07 and 11-08)

Done:

- [x] **Schedule** (`schedule_page.dart` 805 -> 226 lines, `schedule_task_page.dart` 850 -> 293, shared pieces in `presenter/widgets/`):
  - Day / Week / Month views (Month is the original calendar and stays the default; the choice is kept for the session).
  - One shared job card (time, title, status chip, site, grade, technician, Assign / Reassign).
  - Technician filter chips (All, Unassigned, each technician), applied to every view; deep link `?technician=`.
  - **Tap-to-assign** for every role except technician, from cards, the split-panel and daily-agenda month layouts, and the task detail; **Unassigned** option clears the assignee (and the cloud column).
  - The timeline layout stays tap-to-detail (no room for a button).
- [x] **Equipment search** (`equipment_search_page.dart` 1,112 -> 203 lines, six widget files): recent searches (last 8), a two-pane layout on tablets at 900 px or wider (list left, asset summary and actions right: Open inspection, Open full history, Parts profile, Edit site assignment), and a **Scan** button (nameplate serials / QR) via `mobile_scanner`, shown only on Android and iOS. The scanner needs the CAMERA permission (added to the Android manifest).
- [x] **Documents hub**: type chips with counts, date groups, sort, search, Open / Print / Share / Email, delete with Undo, multi-select, summary line and Clear old files (see `email_and_documents.md`).
- [x] **Sync centre, offline banner and the 100-item stall fix**, last-synced time saved across relaunches, and a "Not uploaded yet" badge on maintenance list cards (see `offline_sync_and_backup.md`).

## 9. Remaining items closed (2026-11-08)

Done:

- [x] **Inspections list** (`inspection_list_page.dart`): saved filter presets (chips; tap applies, long-press renames or deletes; built-ins "This week" and "Needs follow-up"; stored in preferences), Green / Amber / Red status chips and a search box (address, site code, technician, customer; an inspection has no trade field, so there is no trade filter), swipe left to delete with a 6-second Undo (admin and supervisor only; the real delete and its sync happen after the window), swipe right to schedule a maintenance job from the inspection, and a comfortable / compact density toggle (remembered).
- [x] **Inspection form**: an "N unanswered" chip opens a grouped list (site code, grade, address, unticked checklist items with no note, customer name, both signatures); tapping an item scrolls to its section (`domain/inspection_unanswered.dart`; the form has no per-field keys, so it jumps to the section).
- [x] **Settings** regrouped: Account, Appearance, Notifications, Data & Sync (with a "Sync centre" row), PDF (template, summary page), Advanced (template management, selection options, debug tools), About.
- [x] **Login** split from 962 to 216 lines (`presenter/widgets/login/`): real validation (email shape, non-empty password), inline errors after a field is touched, disabled button and spinner while submitting, show / hide password, next / done keyboard actions, autofill hints. The dev "Skip login" button now shows only in debug builds (`kDebugMode`), never in profile or release.
- [x] **1.3x text** checks added for settings, login and the maintenance wizard (Site Information, Parts & Materials, Signatures) on phone and both tablet orientations. They found and fixed overflows in the walkthrough and signatures sections.
- [x] **Dark mode and contrast**: `test/shared/contrast_test.dart` checks WCAG AA for chips, buttons, snackbars, fields, tiles and stat cards in light and dark. Light-mode success / warning / info / error colours, input borders and hint text were adjusted in the theme tokens.
- [x] **Page transitions** (`core/theme/app_transitions.dart`, via the theme's page transitions): 220 ms fade for sections, fade and short slide-up for pushed screens, none when the device's reduce-motion setting is on.
- [x] **Performance**: Stock, Parts Catalog, Vendors and the part picker build lazily; the Movements ledger shows 50 rows at a time with "Show more"; photo thumbnails decode at display size (`shared/widgets/thumbnail_image.dart`); `select` on the auth provider in the drawer and role guard.
- [x] **Maintenance list** "In progress - 3 of 8" step count (one materials pass and one photo lookup per unfinished record).
- [x] **Timeline month layout** has the Assign / Reassign button on task cards.
- [x] **Testability seam** for opening, printing and sharing documents (`documentActionsProvider`), with tests for the hub and the vehicle Documents tab.
- [x] A share failure in the PDF viewer now shows an error message.
- [x] **Signature pads in dark mode**: a signature is a document artifact (exported as a PNG and printed on PDFs), so it is always black ink on a white "paper" surface whatever the app theme. The pads therefore stay light in dark mode but get a visible mid-grey outline (3:1 against the dark and light surfaces), a baseline and a "Sign here" hint (4.5:1 on the paper); the caption and buttons around them use theme colours. Saved signatures are previewed on the same paper so dark ink never lands on a dark background. One shared widget set (`shared/widgets/signature_surface.dart`: `SignaturePaper`, `SignatureImagePreview`) and tokens (`core/theme/signature_palette.dart`) are used by the maintenance, inspection and vehicle-inspection pads and the vehicle detail sheet. The pad fills the width up to 560 dp with a 140 to 240 dp height. Pen and export colours are unchanged, so stored PNG bytes are identical in both themes. Tested in `test/shared/signature_surface_test.dart` (contrast, phone and both tablet orientations, 1.3x text, rotation, exported pixels).

## 10. Follow-up round (2026-11-07) and what is still open

Done:

- [x] **Share, export, print and email actions** all catch failures (`lib/shared/widgets/action_runner.dart`, `runUserAction`): a failure shows "Could not <action>. Please try again." (details only in the log), a cancelled save or share shows nothing, and email, PDF generation and Settings export show busy feedback. Covered: document share / print / share-many, document email, PDF viewer share, Settings Export Data, usage report CSV, purchase order share, maintenance PDF export and print, inspection detail PDF, and the share step after a PDF is saved (a failing share sheet no longer makes a saved PDF look failed).
- [x] **Lists build lazily** everywhere a user-data list can grow: purchase orders, schedule day list and daily agenda, Jobs list, customer directory, Shortages and Job Needs were converted; the Documents hub, equipment results, vehicle list and maintenance list were already lazy. Eight laziness tests (300 generated rows, fewer than 60 built).
- [x] **Vehicle inspections upload** and show the "Not uploaded yet" badge on the Vehicle Inspection Log and the vehicle's Inspections tab (see `offline_sync_and_backup.md`).
- [x] **Hard-coded colours** reviewed; signature pads and previews use one theme-independent paper surface (section 9). Intentionally left fixed: black 5% shadows (`inspection_form_page.dart`, `inspection_detail_page.dart`, `equipment_search_bar.dart`), the `Colors.black54` saving scrim, and photo overlays and the full-screen photo viewer. PDF colours are separate from the app theme.

Still open:

- Migration `supabase/migrations/20261109100000_vehicle_inspections.sql` is written but **to run** (not applied). Until it is run, vehicle inspections queue and show the badge but the upload fails and retries.
- A second device sees an uploaded vehicle inspection record, but its signature and photo file paths point at the first device's files; the image files are backed up separately and how they display on another device is not verified.
- Transitions: a section change that keeps the old page underneath may slide instead of fading; not checked on a device.
- Inspections: the "unanswered" rule in the form is a first definition (site code, grade, address, unticked checklist items without a note, customer name, both signatures); the swipe-right schedule action is not widget-tested; delete is limited to admin and supervisor.
- Settings keeps an "Advanced" group outside the five planned groups.
- The dev sign-in code in `auth_controller.dart` is still gated only by the build flag (the login button itself is debug-only).
- Pages not converted to lazy lists on purpose: Settings, About, admin and debug pages, template management, profile approvals, the week-bounded calendar list, and the inspections lists.
- `test/inspections/pdf_export_test.dart` is flaky when run inside the full suite (a temp directory is removed while the sync queue writes); it passes alone.
