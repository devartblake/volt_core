# Fleet & vehicle assets — implementation plan

**Date:** 2026-08-25
**Status:** 🚧 Phases 1–3 built. Phases 4–5 proposed.
**Scope:** Two new capabilities — vehicle records with a maintenance checklist,
and the tool inventory carried in each vehicle with its signed hand-over
receipt.

**Decisions taken (2026-08-25), replacing the open questions they answer:**

- **Naming confirmed.** Fleet for vehicles, Vehicle Assets for the tools.
  Neither goes into `public.equipment`, which stays the field-service assets we
  inspect. (§0, §1)
- **Access resolved, and it is not "every role except tech".** A technician is
  stationed to a specific vehicle, is responsible for it and its assets, and
  signs for it when it is dispatched — daily. So a tech reads *their* vehicle;
  dispatch does the data entry and owns the fleet record. §3 below is rewritten
  to match; the original either/or is settled as **(b)**.

Derived from two paper forms currently in use:

| Form | What it captures |
| --- | --- |
| **Vehicle Maintenance Checklist** | Per vehicle: VIN, make/model, mileage, licence plate, last oil change, last lubricant check, brake check status, odometer at last service, battery health, notes. Headed by a vehicle designation (`Truck A`) and a date. |
| **Asset receipt** | Per van, per shift: operator / co-operator, dispatcher, date-time, driver signature, and a line per tool — nomenclature, part number, qty, serviceable (FMC / NMC), missing (yes/no), reason. Headed by a vehicle designation (`Work Van B`) and a five-clause asset disclaimer the signer accepts. |

---

## 0. Read this first: a name collision

The app already has an **Equipment** module. It means *the assets we inspect* —
generators, transfer switches, switchgear — backed by `public.equipment`, with
`asset_type` and an `identity_key` derived from serial or inspection history.

The request's "equipment management for the vehicles" is a **different thing**:
benders, fish tapes, ladders, extension cords, vacuums, rod sets, push carts —
tools issued to a van and signed for by a driver.

Two unrelated concepts, one word. If both ship as "equipment", every future
conversation, table name and search box is ambiguous. This plan uses:

| Concept | Code namespace | UI label |
| --- | --- | --- |
| Assets we inspect (existing) | `modules/equipment`, `public.equipment` | Equipment · Registry |
| Vehicles (new) | `modules/fleet`, `public.fleet_vehicles` | Fleet |
| Tools carried in a vehicle (new) | `modules/fleet`, `public.vehicle_assets` | Vehicle Assets |

**Decide this before any code is written.** Renaming after the tables exist
costs a migration and a sync-payload change.

---

## 1. Should vehicles reuse `public.equipment`?

Migration `0006_phase1_asset_foundation.sql` explicitly invites it:

> Asset vocabulary: existing equipment remains compatible and becomes the
> shared registry for all field-service asset types.

**Recommendation: no — give vehicles their own table.** The invitation is real
but the fit is not:

- **Identity is different.** `equipment` is keyed by
  `v5(namespace, "<tenant>|<identity_key>")` with `unique (tenant_id,
  identity_key)`, where `identity_key` is a serial number, a site composite, or
  an inspection id. A vehicle's identity is its VIN, which wants its own unique
  constraint and its own validation.
- **The columns are inspection-shaped.** `latest_inspection_id`,
  `inspection_count`, `last_inspection_at`. A vehicle has an odometer, a plate,
  and service intervals. Those would all land in `metadata` jsonb — no
  constraints, no indexes, and every "which vehicles are due for service?"
  query becomes a jsonb scan.
- **The lifecycle is different.** Equipment rows are *derived* from inspections
  on many devices, which is why they merge by upsert. Vehicles are entered once
  by the office and edited deliberately.

**What you give up** is unified asset search. Recover it cheaply later with a
read-only view (`asset_search_index`) unioning the two, rather than by
distorting either table's shape now.

---

## 2. Data model

Four tables. The asset receipt is a classic header/lines pair, and modelling it
that way is what makes "show me every time this ladder went missing" answerable.

```
fleet_vehicles ──┬── vehicle_maintenance_checks   (one per inspection of the vehicle)
                 │
                 ├── vehicle_assets               (a tool instance assigned to this vehicle)
                 │
                 └── vehicle_asset_checks ──── vehicle_asset_check_lines
                        (the signed receipt)          (one row per tool, per receipt)

vehicle_asset_catalog ──── vehicle_assets         (what a tool *is*, vs. which van has it)
```

### 2.1 `fleet_vehicles`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | uuid pk | |
| `tenant_id` | uuid not null | RLS anchor |
| `designation` | text not null | `Truck A`, `Work Van B` — how the crew refers to it |
| `vin` | text | 17 chars; `unique (tenant_id, vin)` where not null |
| `license_plate` | text | |
| `make`, `model` | text | |
| `model_year` | int | |
| `vehicle_type` | text | `van` \| `truck` \| `other` |
| `odometer` | int | Current reading, updated by each check |
| `status` | text | `active` \| `maintenance` \| `out_of_service` \| `retired` — see §11 for why not `in_service` |
| `notes` | text | |
| audit | `created_at`, `updated_at`, `updated_by` | matches the other tables |

`designation` is the human key and should be unique per tenant among
non-retired vehicles. VIN is nullable because a vehicle gets added before
somebody walks out to read the VIN off it.

### 2.2 `vehicle_maintenance_checks`

One row per completed checklist. **The checklist is an event, not a set of
columns on the vehicle** — the paper form is filled in repeatedly and the
history is the point.

`vehicle_id`, `tenant_id`, `checked_at`, `checked_by_user_id`, `odometer`,
`last_oil_change_at`, `last_lubricant_check_at`, `brake_status`,
`odometer_at_last_service`, `battery_status`, `notes`.

Status fields (`brake_status`, `battery_status`) are short enums —
`ok` / `attention` / `fail` — not free text, so "which vehicles have a failing
brake check?" is a query rather than a grep.

Denormalise the latest values onto `fleet_vehicles` (`odometer`,
`last_check_at`) so the list screen does not need a correlated subquery.

### 2.3 `vehicle_asset_catalog`

The master list of tool *types*: `name` ("IDEAL ½ EMT BENDER"), `part_number`
("74-031"), `category`, `is_active`. Tenant-scoped.

Separating catalog from assignment is what stops "IDEAL ½ EMT BENDER" being
typed five slightly different ways across five vans.

### 2.4 `vehicle_assets`

A specific tool assigned to a specific vehicle: `vehicle_id`, `catalog_id`,
`quantity`, `serial_number` (nullable), `condition`, `assigned_at`.

**Model per instance, not per quantity.** The paper form lists the two Werner
8 ft ladders as two separate lines with qty 1 each — and on the sample, one of
them is missing and the other is not. A single row with `quantity: 2` cannot
express that.

### 2.5 `vehicle_asset_checks` + `vehicle_asset_check_lines`

**Header** (`vehicle_asset_checks`): `vehicle_id`, `tenant_id`, `checked_at`,
`operator_user_id`, `co_operator_user_id`, `dispatcher_user_id`,
`signature_path`, `disclaimer_version`, `notes`.

**Lines** (`vehicle_asset_check_lines`): `check_id`, `vehicle_asset_id`,
`quantity_expected`, `readiness`, `is_missing`, `reason`.

- `readiness` is `fmc` / `nmc` — Fully / Non Mission Capable, the terms already
  printed on the form. Keep the crew's vocabulary; don't invent "ok/broken".
- `disclaimer_version` matters: the receipt is a signed acceptance of five
  liability clauses. If that wording is ever revised, a stored signature must
  still say which text was agreed to. **Version it from day one** — it cannot be
  reconstructed later.

---

## 3. Access control

**A technician is stationed to one vehicle.** They are responsible for it and
for its assets, and they sign for it when it is dispatched — a daily event, on
the digital version of the receipt. Dispatch does the data entry; the driver
signs.

That makes the rule per-row, not per-role alone:

| | Technician | Supervisor · Dispatcher · Admin |
| --- | --- | --- |
| See the vehicle list | ✅ their assigned vehicle only | ✅ whole fleet |
| Open a vehicle's detail | ✅ theirs | ✅ any |
| Add / edit a vehicle | ❌ | ✅ |
| Sign the daily receipt (phase 4) | ✅ theirs | ✅ |

```dart
// lib/app/route_roles.dart — built
'fleet':                {tech, supervisor, dispatcher, admin},
'fleet_vehicle_detail': {tech, supervisor, dispatcher, admin},
'fleet_vehicle_new':    {supervisor, dispatcher, admin},
'fleet_vehicle_edit':   {supervisor, dispatcher, admin},
```

**RouteRoles decides which screens open, not which rows come back.** The
narrowing to one vehicle is `fleet_vehicles_read` in the database, mirrored
locally by `fleetVisibleVehiclesProvider`. `assigned_to_user_id` is therefore
not a detail on the form — it is what makes the vehicle visible to its driver
at all, and clearing it takes the vehicle off their device.

Two things this gets for free:

1. `RouteRoles` is default-deny, and `test/app/route_roles_test.dart` fails if
   a `RouteNames` constant is missing from both the role map and the public
   list. Adding a route without an RBAC decision is impossible.
2. `AppDrawer` filters through `RouteRoles.isAllowedByName`, so no separate
   drawer logic is needed.

`test/fleet/fleet_route_roles_test.dart` pins the split itself, which
completeness cannot: granting tech `fleet_vehicle_edit` by accident would pass
the coverage test and hand a driver the ability to reassign their own van.

---

## 4. Row-level security

Follow `20260824231000_tenant_role_assignment_audit.sql`, which has the shape
this project settled on.

```sql
alter table public.fleet_vehicles enable row level security;
grant select, insert, update, delete on public.fleet_vehicles to authenticated;

create policy fleet_vehicles_read on public.fleet_vehicles
  for select to authenticated
  using ((select public.is_tenant_member(tenant_id)));

create policy fleet_vehicles_write on public.fleet_vehicles
  for all to authenticated
  using ((select public.can_manage_tenant_work(tenant_id)))
  with check ((select public.can_manage_tenant_work(tenant_id)));
```

`can_manage_tenant_work()` already means *admin, supervisor or dispatcher* —
exactly the role set requested. **Use it rather than open-coding the list**, so
the database and `RouteRoles` cannot drift apart.

> **Do not repeat the `tenant_members` mistake.** That table shipped with RLS
> enabled and only a `SELECT` policy, so every write failed with `42501` for
> everyone including admins, and the Team & Roles screen was inert for months
> before anyone noticed. **Write a policy per operation, and grant the table.**
> A read-only policy set is silent until someone tries to save.

---

## 5. Offline behaviour and sync

Vehicle checks happen in a yard or a garage, which is exactly where signal is
worst. Treat these as offline-first, like inspections:

- Hive box per aggregate; the local write is the source of truth for the UI.
- `SyncService.enqueueUpsert(table:, id:, payload:)` for the outbound row.
- **Every payload must carry `tenant_id`.** The queue re-stamps stale tenants at
  drain time (`retagQueuedRow`), but it only touches rows that already have the
  column — a payload without it is skipped and will fail RLS forever.
- Deterministic ids (uuid v4 generated client-side) so an upsert retried after a
  crash merges instead of duplicating.

### Hive adapters

Any new Hive model must follow the convention established in
`test/support/hive_adapter_probe.dart`:

- new fields get `@HiveField(n, defaultValue: ...)` or a nullable constructor
  parameter, so a row written before the field existed still decodes;
- add an `_AdapterCase` to `test/storage/hive_adapter_forward_compat_test.dart`
  — its `every registered Hive adapter is covered` test asserts the case count
  and will fail if a new adapter is registered without one.

---

## 6. Screens

| Route | Screen | Notes |
| --- | --- | --- |
| `/fleet` | Vehicle list | Designation, type, plate, odometer, status chip, "service due" flag |
| `/fleet/new`, `/fleet/edit/:id` | Vehicle form | VIN validated to 17 chars; plate free text |
| `/fleet/detail/:id` | Vehicle detail | Tabs: **Overview** · **Maintenance history** · **Assets** |
| `/fleet/:id/maintenance/new` | Maintenance checklist | Mirrors the paper form field-for-field |
| `/fleet/:id/assets` | Assigned tools | Add from catalog, adjust condition, unassign |
| `/fleet/:id/asset-check/new` | Asset receipt | Header + one row per assigned tool, signature, PDF |
| `/fleet/catalog` | Tool catalog | Admin-only |

Reuse what exists rather than rebuilding: `AppPage` for chrome, `LabeledField`
/ `SelectionField` for inputs, `StatusSwitchTile` (which now carries the YES/NO
badge) for the missing/serviceable toggles, the inspection signature capture,
and `PdfTemplate` for the printed receipt.

The asset-check screen is close to the post-inspection checklist: a list of
items, a yes/no answer each, a per-item reason. **Look at
`SectionPostInspection` and `kInspectionChecklist` before writing it** — the
per-item note dialog and the single-source item list are directly applicable.

---

## 7. Phasing

Ordered so each phase is independently useful and independently revertable.

| Phase | Deliverable | Rough size |
| --- | --- | --- |
| **1** ✅ | Migration for `fleet_vehicles` + RLS; entity, Hive model, repo, sync; list / detail / form; RBAC + drawer | Done — see §11 |
| **2** ✅ | `vehicle_maintenance_checks`; checklist form; history tab; latest-values denormalisation | Done — see §12 |
| **3** ✅ | `vehicle_asset_catalog` + `vehicle_assets`; catalog admin screen; per-vehicle assignment | Done — see §13 |
| **4** ✅ | `vehicle_asset_checks` + lines; receipt screen; dual signature; PDF; depots; disclaimer versioning | Done — see §14 |
| **5** | Service-due rules (odometer or elapsed time), dashboard tile, out-of-service surfacing | Small, high visibility |

Phase 5 is where this stops being a filing cabinet and starts preventing a
missed brake service. Do not let it fall off the end.

Phase 6, added during phase 4, is real push notification — see §9.2 for why
it is separate and what the app does instead until then.

---

## 8. Testing

- **RBAC:** `route_roles_test.dart` covers completeness automatically; add an
  explicit case asserting tech is refused each new route.
- **Hive:** an `_AdapterCase` per new adapter (§5).
- **Sync payload:** assert `tenant_id` is present and the round trip preserves
  every field — the pattern in `test/inspections/checklist_conclusions_test.dart`.
- **Domain:** VIN validation; service-due arithmetic across both odometer and
  elapsed-time rules; "missing" line requires a reason.
- **Widget:** the receipt cannot be submitted unsigned.

---

## 9. Open questions

1. ~~Tech access vs. the driver's signature.~~ **Settled** — see §3. The tech
   is the driver, signs daily, and dispatch does the data entry.
2. ~~Does a missing tool raise anything?~~ **Settled** — it is recorded on the
   receipt, it raises a notification, and admin or dispatch then creates a work
   order from it. Note what "notification" can mean today: the app has no push
   infrastructure at all (`NotificationService` is `flutter_local_notifications`,
   which only reaches the device that scheduled the reminder), so phase 4 ships
   the in-app half — a dashboard card, a fleet-list banner and a per-vehicle
   badge, all fed by `fleetAttentionProvider`. Real push is **phase 6**: FCM,
   APNs, a device-token table and an edge function, plus its own store
   disclosure. Do not let the word "notification" hide that gap.
3. ~~Do vehicles belong to a depot or site?~~ **Settled** — a depot, which is
   *not* a `site`. `sites` holds customers' service locations; a depot is the
   tenant's own yard. Phase 4 adds `fleet_depots` and `fleet_vehicles.depot_id`
   rather than reusing `site_id`, which would have put A&S's own garage in the
   customer list. A&S runs one depot, so the vehicle form states it and selects
   it instead of offering a dropdown of one; add a second row and the field
   becomes a chooser with no code change.
4. ~~Retention.~~ **Settled** — asset receipts are *not* covered by
   `tenant_retention_policies`. They belong to a vehicle, and they are evidence
   of what somebody signed for, so nothing deletes them on a timer. Retiring or
   deleting a vehicle does not remove its receipts. No retention period was
   specified, so none is enforced; if one is ever wanted it is a new policy
   column and a job, not a change to this table.
5. ~~Odometer trust.~~ **Settled** — refused by default, overridable with an
   explicit confirmation. See §12.
6. ~~Disclaimer wording.~~ **Settled** — the admin owns it. Wording lives in
   `fleet_disclaimers`, admin-only to publish, and **a published version is
   never edited**: `authenticated` holds `select` and `insert` on that table and
   nothing else, so revising means inserting version N+1. An existing signature
   is never re-accepted; it keeps pointing at the version it was given for, and
   a reprint fetches that version's text rather than today's.

Still open after phase 4:

7. **Retention period**, if one is ever required (see 4).
8. **Push notifications** (see 2) — whether phase 6 is worth its own store
   disclosure and Apple account work.

---

## 10. What this plan deliberately does not do

- **No changes to `public.equipment`.** Vehicles are a separate table (§1);
  unified search is a later view, not a schema compromise now.
- **No GPS, telematics, fuel cards or route planning.** Out of scope.
- **No tech-facing screens.** Per the stated access rule, with the seam for
  adding them left open (§3).


---

## 11. Phase 1 — what was built

| Area | Files |
| --- | --- |
| Migration | `supabase/migrations/20260825140000_fleet_vehicles.sql` |
| Domain | `modules/fleet/domain/entities/vehicle_entity.dart` |
| Storage | `infra/models/vehicle_record.dart` (typeId 75), `infra/datasources/vehicles_box.dart` |
| Sync | `infra/mappers/vehicle_supabase_mapper.dart`, `infra/datasources/vehicle_remote_datasource.dart` |
| Repository | `infra/repositories/vehicle_repository{,_impl}.dart` |
| Presenter | `presenter/fleet_providers.dart`, `presenter/pages/vehicle_{list,detail,form}_page.dart` |
| Wiring | `route_paths.dart`, `app_router.dart`, `route_roles.dart`, `app_drawer.dart`, `hive_adapters.dart`, `hive_service.dart` |
| Tests | `test/fleet/` (3 files, 37 cases) + a `VehicleRecordAdapter` case in the forward-compat suite |

Decisions worth knowing before phase 2:

- **`status` is stored `out_of_service`, not `outOfService`.** `VehicleStatusX.wire`
  exists for the same reason `UserRoleX.wire` does — the check constraint
  rejects the enum's own `name`.
- **`maintenance`, not the plan's `in_service`.** "In service" reads as both
  "in use" and "being serviced", which are opposites here.
- **Duplicate designation and duplicate VIN are caught in the repository**, not
  left to surface as an opaque `23505` from the partial unique indexes seconds
  later. Designations are reusable once a vehicle is retired.
- **A blank VIN is stored as `null`, never `''`** — the unique index is partial
  (`where vin is not null`), so `''` would collide every un-VINed vehicle with
  every other one.
- **VIN rejects I, O and Q**, which the standard excludes because they are
  misread as 1 and 0. That is the transcription error to catch at the keyboard.
- `LabeledField` gained `inputFormatters` along the way; the year and odometer
  fields wanted digits-only rather than a validator scolding after the fact.

**Not done, and deliberately visible:** the detail page carries two "arrives in
phase N" cards where maintenance history and assets will go, rather than a
blank area that reads as a bug.


---

## 12. Phase 2 — what was built

| Area | Files |
| --- | --- |
| Migration | `supabase/migrations/20260825160000_vehicle_maintenance_checks.sql` |
| Domain | `domain/entities/vehicle_maintenance_check.dart` |
| Storage | `infra/models/vehicle_maintenance_check_record.dart` (typeId 76), its box |
| Sync | `infra/mappers/vehicle_maintenance_check_supabase_mapper.dart` |
| Repository | `infra/repositories/vehicle_check_repository.dart` |
| Presenter | `presenter/pages/vehicle_maintenance_form_page.dart`, history section on the detail page |
| Tests | `test/fleet/vehicle_check_repository_test.dart` (18 cases) |

### The odometer question, settled

A reading lower than the vehicle already shows is **refused by default** and
retryable with `allowOdometerRollback: true`, which the form surfaces as a
dialog naming both numbers.

It is overwhelmingly a transposed digit on a six-figure number. But it is
legitimately a correction after a cluster replacement, so refusing outright
would make the app wrong about a real vehicle. Refuse-then-confirm catches the
common case at the keyboard and keeps the rare one recordable, with the person
entering it having said out loud that they meant it.

### Cached values only ever move forward

`fleet_vehicles.odometer` and `last_check_at` are denormalised so the list does
not need a correlated subquery. Both are advanced in two places that must
agree:

- the repository, so the list is right immediately after a save while offline;
- `refresh_vehicle_check_cache()`, so it is still right when a *second* device
  syncs a check the first has never seen.

Both take the **maximum**, never the latest write. Checks get entered out of
order — June's typed in first, March's caught up later — and a backdated check
must not report the van as more recently inspected than it is. There is a test
for exactly that interleaving; a simpler "backdated check" test passed even
with the guard removed, because `shouldTouch` short-circuits before the branch
that matters.

### Other decisions

- **A check is an event row**, not columns on the vehicle. The paper form is
  filled in repeatedly and "when was Truck A last serviced, and by whom?" is
  the question it exists to answer.
- **`ok` / `attention` / `fail`, not a boolean.** "Needs watching at the next
  service" is the most common real answer on a walk-around, and collapsing it
  into pass/fail means it is recorded as a pass and forgotten.
- **Dates are sent as calendar days** (`2026-06-05`), not instants. A `date`
  column round-trips a timestamp back with a time the user never entered, which
  renders as a different day either side of midnight.
- **The date picker's `lastDate` is today.** A service date is in the past, and
  allowing next year invites a typo that reads as "serviced recently" forever.
- `_DateField` is keyed on its value — `LabeledField` seeds its controller
  once, so without the key the field keeps showing the old date after a pick.
  The inspection date fields had this exact bug.

**Writing a check is dispatch-only**, matching how the vehicle record itself is
managed. Letting a technician log their own walk-around is one line in
`RouteRoles` plus one policy in the migration, if that turns out to be how the
work flows.


---

## 13. Phase 3 — what was built

| Area | Files |
| --- | --- |
| Migration | `supabase/migrations/20260825180000_vehicle_assets.sql` |
| Optional seed | `supabase/manual/seed_vehicle_asset_catalog.sql` — the ten tools on the current paper receipt |
| Domain | `domain/entities/vehicle_asset_catalog_item.dart`, `vehicle_asset.dart` |
| Storage | `infra/models/vehicle_asset_catalog_item_record.dart` (typeId 77), `vehicle_asset_record.dart` (78), `infra/datasources/vehicle_asset_boxes.dart` |
| Sync | `infra/mappers/vehicle_asset_supabase_mapper.dart` |
| Repository | `infra/repositories/vehicle_asset_repository.dart` |
| Presenter | `presenter/pages/vehicle_asset_catalog_page.dart`, `vehicle_assets_page.dart`, assets card on the detail page |
| Tests | `test/fleet/vehicle_asset_repository_test.dart` (26 cases) |

### No quantity column

**One row per physical item.** The paper form lists the two Werner 8ft ladders
as two separate lines, and on the sample one is missing and the other is not. A
single row carrying `quantity: 2` cannot express that — which is the whole
reason the receipt exists.

Adding a quantity later would be additive, but it would reintroduce exactly the
ambiguity this avoids. If a genuinely countable consumable turns up, catalog
the container ("box of connectors") rather than the count.

### Access

| | Tech | Supervisor · Dispatcher | Admin |
| --- | --- | --- | --- |
| See their van's tool list | ✅ | ✅ (all vans) | ✅ |
| Add / edit / retire a tool on a van | ❌ | ✅ | ✅ |
| Curate the catalog | ❌ | ❌ | ✅ |

The catalog is **admin-only**, unlike the rest of the fleet: a sloppy catalog is
precisely what splitting catalog from assignment exists to prevent. Everyone can
*read* it, because a technician needs the tool's name to make sense of their own
van's list.

Writes stay with dispatch throughout — confirmed 2026-08-25 that a technician
does **not** log their own walk-around.

### Other decisions

- **FMC / NMC**, not "ok / broken". The words on the screen are the words on the
  form the technician has been signing for years.
- **`is_missing` is separate from `retired_at`.** A missing ladder is expected
  back; a retired one is not. Retiring clears missing, or the tool would sit on
  the attention list forever.
- **Serials are unique across the fleet** — the same numbered tool cannot be in
  two vans — but only among *non-retired* assets, so a replacement can inherit
  the number. Blank serials store as `null`, never `''`, or every unserialised
  tool would collide with every other one on the partial index.
- **`catalog_id` is `on delete restrict`.** Deleting a catalog entry vans still
  carry would orphan real tools; deactivate it instead.
- **An asset cannot be moved to a different catalog entry after creation.** That
  would silently rewrite what past receipts referred to. Retire it and add the
  right one.
- **A row whose catalog entry has not synced still renders**, as "Unknown tool ·
  <serial>". Dropping it would hide exactly the tool somebody needs to ask
  about.
- Anything missing or NMC **sorts to the top** and gets a banner. That is why
  somebody opened the screen.

---

## 14. Phase 4 — what was built

The signed asset receipt: the phase that actually replaces the paper.

| Area | Files |
| --- | --- |
| Migration | `supabase/migrations/20260825200000_vehicle_asset_checks.sql` |
| Seeds | `supabase/manual/seed_asset_disclaimer.sql`, `supabase/manual/seed_fleet_depot.sql` |
| Domain | `domain/entities/vehicle_asset_check.dart`, `asset_disclaimer.dart`, `fleet_depot.dart` |
| Storage | `infra/models/vehicle_asset_check_record.dart` (typeIds 79, 80), `fleet_reference_records.dart` (81, 82), `infra/datasources/vehicle_asset_check_boxes.dart` |
| Sync | `infra/mappers/vehicle_asset_check_supabase_mapper.dart` |
| Repository | `infra/repositories/vehicle_asset_check_repository.dart` |
| PDF | `infra/services/asset_receipt_pdf_service.dart` |
| Presenter | `presenter/pages/vehicle_asset_receipt_page.dart`, `presenter/widgets/{asset_disclaimer_dialog,signature_pad_dialog,fleet_attention_card}.dart` |
| Tests | `test/fleet/asset_receipt_test.dart` (26 cases), `test/lint/no_escaped_interpolation_test.dart`, extended RBAC + forward-compat suites |

### The flow, in order — the order is the point

1. dispatch fills the header and walks the tool list with the driver;
2. the driver is shown the disclaimer in a **blocking modal** whose Accept
   button only enables once the text has been scrolled to the end;
3. the driver signs, and each line's answer becomes the van's standing state;
4. dispatch counter-signs as a second verification, which freezes the receipt.

Step 2 is not a checkbox labelled "I agree". A checkbox reproduces the signature
without reproducing the reading, which is the one thing the paper's boxed
clauses above the signature line actually achieve.

### Decisions worth knowing

- **Every line snapshots the tool's name, part number and serial.** Not a join.
  A receipt records what somebody signed for on a particular morning; correcting
  a catalog typo in 2027 must not retroactively edit the 2026 paper.
- **Immutability is a trigger, not an RLS policy.** The client writes through a
  retrying offline outbox, so an identical re-send of a finalised row has to be
  allowed through — a blanket "reject every update" would jam the queue behind a
  write that can never succeed. The trigger compares `to_jsonb(new) - 'updated_at'`
  against the old row and only raises when something actually differs. Putting
  the rule in the policy instead would turn that retry into a permanent `42501`.
- **No unique index on (vehicle, date).** Vans go out twice and drivers swap
  mid-shift; a uniqueness rule here would surface as a `23505` in a yard with no
  signal, which is the worst possible place to hit one.
- **Signatures store the LOGICAL path**, unlike inspection signatures, which
  store the device path. A receipt is reprinted in the office from a different
  machine than it was signed on, where `/data/user/0/...` resolves to nothing and
  the box prints empty with nothing to explain it. The PDF says either "Not
  signed" or "Signed — image not on this device", which call for different
  reactions.
- **Lines carry `is_missing` → reason as a database check constraint**, not only
  a UI rule. A missing ladder with no explanation tells nobody anything.
- **The receipt prefills FMC and present**, and carries yesterday's problem
  forward rather than resetting it. Making a driver re-report the same broken
  ladder every morning is how a form starts being signed without being read.
  The trade-off is real: prefilling makes rubber-stamping easy, and that was
  accepted deliberately because the paper is a checklist, not a survey.
- **The disclaimer has two sources on purpose** — `kBuiltInDisclaimerClauses` in
  Dart so a device that has never synced can still show the terms, and the seed
  SQL for the database. `test/fleet/asset_receipt_test.dart` fails on a
  one-comma difference between them, because two sources of a legal clause is
  one too many.
