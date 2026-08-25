# Fleet & vehicle assets — implementation plan

**Date:** 2026-08-25
**Status:** 📋 Proposed. Nothing built yet.
**Scope:** Two new capabilities — vehicle records with a maintenance checklist,
and the tool inventory carried in each vehicle with its signed hand-over
receipt. Available to supervisor, dispatcher and admin; not to tech.

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
| `status` | text | `active` \| `in_service` \| `out_of_service` \| `retired` |
| `notes` | text | |
| audit | `created_at`, `updated_at`, `updated_by` | matches the other tables |

`designation` is the human key and should be unique per tenant among
non-retired vehicles. VIN is nullable because a vehicle gets added before
somebody walks out to read the plate off it.

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

The request: every role except tech.

```dart
// lib/app/route_roles.dart
const _fleetRoles = {UserRole.supervisor, UserRole.dispatcher, UserRole.admin};

'fleet': _fleetRoles,
'fleet_vehicle_new': _fleetRoles,
'fleet_vehicle_detail': _fleetRoles,
'fleet_vehicle_edit': _fleetRoles,
'fleet_maintenance_new': _fleetRoles,
'fleet_assets': _fleetRoles,
'fleet_asset_check_new': _fleetRoles,
'fleet_catalog': {UserRole.admin},   // editing the master tool list
```

Two things this gets for free:

1. `RouteRoles` is **default-deny**, and `test/app/route_roles_test.dart` fails
   if a `RouteNames` constant is missing from both the role map and the public
   list. Adding a route without an RBAC decision is already impossible.
2. `AppDrawer` filters through `RouteRoles.isAllowedByName`, so the Fleet
   section disappears for tech with no separate drawer logic.

### ⚠️ This conflicts with the paper workflow

**The asset receipt is signed by the driver, and the driver is a technician.**
The sample names two operators in the signature block and has a
`[X] Driver INITIAL / SIGNATURE` line at the top.

Excluding tech entirely means one of:

- **(a)** dispatch does the data entry from a paper form the driver still signs
  — the app becomes a record of a paper process, and the signature is a scan or
  is lost; or
- **(b)** techs eventually need a narrow, tech-visible signing screen.

This plan implements **(a)** as asked. Design for **(b)** by keeping the
signature on the *check header*, not on the vehicle, so a tech-facing "sign for
my van" route can be added later without touching the schema.

Worth settling before Phase 4 — it changes who the receipt screen is built for.

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
| **1** | Migration for `fleet_vehicles` + RLS; entity, Hive model, repo, sync; list / detail / form; RBAC + drawer | Largest — establishes the module skeleton |
| **2** | `vehicle_maintenance_checks`; checklist form; history tab; latest-values denormalisation | Medium |
| **3** | `vehicle_asset_catalog` + `vehicle_assets`; catalog admin screen; per-vehicle assignment | Medium |
| **4** | `vehicle_asset_checks` + lines; receipt screen; signature; PDF | Largest of the asset work |
| **5** | Service-due rules (odometer or elapsed time), dashboard tile, out-of-service surfacing | Small, high visibility |

Phase 5 is where this stops being a filing cabinet and starts preventing a
missed brake service. Do not let it fall off the end.

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

1. **Tech access vs. the driver's signature** (§3). The most consequential one —
   it decides who Phase 4 is built for.
2. **Does a missing tool raise anything?** A missing ladder on a signed receipt
   is currently just ink. It could open a work order, notify dispatch, or mark
   the vehicle `out_of_service`. Cheap to add at Phase 4, awkward to retrofit.
3. **Do vehicles belong to a depot or site,** or only to the tenant? Affects
   whether `fleet_vehicles` needs a `site_id`.
4. **Retention.** Inspections keep everything; `tenant_retention_policy` exists
   for archived maintenance. Do asset receipts fall under it?
5. **Odometer trust.** If a maintenance check reports an odometer *lower* than
   the stored one, is that a typo to reject or a correction to accept?
6. **Disclaimer wording** — who owns revisions, and does an existing signature
   need re-acceptance when it changes?

---

## 10. What this plan deliberately does not do

- **No changes to `public.equipment`.** Vehicles are a separate table (§1);
  unified search is a later view, not a schema compromise now.
- **No GPS, telematics, fuel cards or route planning.** Out of scope.
- **No tech-facing screens.** Per the stated access rule, with the seam for
  adding them left open (§3).
