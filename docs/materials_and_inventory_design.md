# Materials and Inventory - Design

Status: **Phases A, B and C built** (2026-11-06); vendors, prices, spreadsheet import and manufacturer grouping added 2026-11-07 (sections 15-17); Phase C completed and Phase D built 2026-11-08 (sections 18-21; the migrations to run are in section 21). The seven decisions in section 10 were all accepted as recommended. All SQL migrations have been applied in Supabase.

## 1. What exists today

| Where | What it holds | Gap |
|---|---|---|
| Inspection form, Materials step (`section_materials.dart`) | Six *dates*: last service, oil filter, fuel filter, air filter, coolant flush, battery replaced | No part numbers, quantities, names, or more than one of anything |
| Maintenance form, Parts & Materials step | Seven free-text boxes (oil type/qty, coolant, filter types, battery, belts, block heater wattage, CDVR serial) | Free text cannot be counted, searched or checked against stock |
| Supabase `maintenance_parts_used` | `category, label, part_number, quantity, unit, notes` per job | Empty and not used by the app |
| Supabase `equipment` | One row per generator (make, model, serial, site) with a `metadata` jsonb | No parts list |
| Fleet `vehicle_asset_catalog` + `vehicle_assets` | A catalog of tool types and the units on each van | A good pattern: catalog + instances |
| Roles | `tech, supervisor, dispatcher, admin` | There is no "super admin" |

## 2. The idea in one picture

Four different things are being asked for. They must stay separate or the system becomes confusing:

```
 PARTS CATALOG            what a part IS         (part no., name, manufacturer, category)
        |
        +--> GENERATOR PARTS PROFILE    what THIS generator takes   (its filters, battery, heater...)
        |            |
        |            |  inspection finds "oil filter due"
        |            v
        +--> JOB MATERIAL LIST          what THIS job needs         (lines, quantities, status)
                     |
                     v
              INVENTORY (warehouse)     what we HAVE                (stock, reservations, ledger)
```

* **Generator parts profile** - recorded once per generator, reused by every inspection and maintenance.
* **Job material list** - what a specific job needs, built from the profile plus what the inspection flagged.
* **Inventory** - stock in the warehouse. The job list is checked against it: *available / partly available / short*.
* **Usage** - what was actually installed on the day (quantity, date used), which also reduces stock.

## 3. The material slots

Ten slot types, each with the same four fields per item.

| Slot | More than one? | Roles |
|---|---|---|
| Air filter | no | - |
| Fuel filter | **yes** | primary / secondary |
| Oil filter | **yes** | primary / secondary |
| Lube filter | **yes** | primary / secondary |
| Fuel/water separator | no | - |
| Coolant filter | no | - |
| Battery | no (see decision 6) | - |
| Block heater | no | - |
| Racor filter | no | - |
| Additional parts | **yes** | free list |

Fields on every item: **part number, quantity, date used (optional), part name / manufacturer.** I add two that cost nothing and are needed: a **role** (primary / secondary) on multi-item slots, and a **notes** line. For a job line I also add **needs replacement** (see 5).

Rules:
* Part number is the key. Typing it searches the catalog and fills name and manufacturer; an unknown part number can still be entered and is offered for adding to the catalog later (a technician on a roof must never be blocked).
* Quantity is a whole number, default 1. Date used is blank until it is true ("Not recorded"), never auto-filled.
* A multi-item slot always has at most one **primary**; the app enforces that.

## 4. Data model

New Supabase tables (all with `tenant_id`, `created_at`, `updated_at`, RLS by tenant):

```
parts_catalog        id, part_number, name, manufacturer, slot_type, unit, min_stock,
                     alt_part_numbers[], is_active, notes            unique(tenant, part_number, manufacturer)

inventory_locations  id, name, kind (warehouse | truck | other)      -- start with one warehouse

inventory_movements  id, part_id, location_id, qty_delta, reason, job_ref, user_id, at, note
                     reason: receive | adjust | reserve | release | issue | return | count
                     (append-only ledger; stock is a sum, so every change is traceable)

inventory_stock      view: part_id, location_id, on_hand, reserved, available = on_hand - reserved

asset_parts          id, equipment_id, slot_type, role, part_id?, part_number, part_name,
                     manufacturer, quantity, last_used_at, notes     -- the generator profile

job_material_lines   id, job_type (inspection | maintenance | work_order), job_id, equipment_id,
                     slot_type, role, part_id?, part_number, part_name, manufacturer,
                     qty_required, qty_reserved, qty_used, date_used,
                     needs_replacement, status
                     status: listed | reserved | issued | used | returned | cancelled
```

* `maintenance_parts_used` is empty, so it is **replaced** by `job_material_lines` rather than kept in parallel.
* The old inspection date columns (`oil_filter_change_date` and so on) stay for existing records. On first open of an old inspection those dates are carried into the matching lines' *date used*; nothing is deleted.
* The app side follows the existing pattern: Hive boxes (adapter-free JSON, like vehicle inspections) for offline, then the sync queue to Supabase. Records get new fields with defaults so older devices keep working.

## 5. How it flows

1. **Set up (once per generator).** On the generator's page, a *Parts* tab lists the ten slots. An admin or supervisor fills the profile; copying from another generator of the same make/model is one tap.
2. **Inspection.** The Materials step opens with the profile pre-filled as "as found". The technician confirms or corrects part numbers and dates, and ticks **needs replacement** on anything due. Corrections offer "update this generator's profile?".
3. **Needs list.** Items flagged on an inspection (and, for a scheduled maintenance, every profile item the service type calls for) become **job material lines**.
4. **Availability check.** Each line shows *In stock (4)*, *Partly (2 of 4)* or *Short*. The dashboard's "Needs attention" gains "parts short for 2 jobs".
5. **Reserve.** A dispatcher or admin reserves the lines for the job: stock is set aside (`reserved`), not removed.
6. **Issue and use.** The warehouse (or the technician) marks parts issued; during the maintenance the technician confirms **qty used** and **date used**. Used quantity leaves stock; unused is returned.
7. **Reorder.** A shortage view adds up everything short across all jobs, minus stock on order, so ordering is one list. Low-stock (`min_stock`) items appear there too.
8. **Reports.** The inspection and maintenance PDFs print a Materials table (slot, part number, name, quantity, date).

## 6. Who can do what

| | Technician | Supervisor | Dispatcher | Admin |
|---|---|---|---|---|
| See a generator's profile, job lists, availability | yes | yes | yes | yes |
| Record / correct materials on their own inspection or maintenance | yes | yes | yes | yes |
| Edit a generator's profile | propose (needs approval) | yes | yes | yes |
| Reserve parts for a job | - | yes | yes | yes |
| Issue / return stock | own jobs | yes | yes | yes |
| Manage the catalog, receive stock, adjust counts, set minimums | - | - | - | yes |

"Super admin": no such role exists. **Recommendation:** treat it as *admin* for now; if you run more than one company in the app later, add an `owner` role above admin that spans tenants. This is decision 3 below.

## 7. Screens

**Inspection / maintenance form - Materials step** (replaces the six date pickers)
* Header line: the generator ("Generac RG048, SN 2101505") and a "Copy from profile" button.
* One card per slot, each with a status chip (*Recorded*, *Needs replacement*, *Empty*). Multi-item slots show *Primary* and *Secondary* rows and an **Add another** button; Additional Parts is a plain list.
* An item row: part number (searchable), name / manufacturer, quantity stepper, date used. On phones the row stacks; on tablets the four fields sit on one line.
* When the job is planned, each line also shows its availability chip.
* Fully usable offline; stock numbers show "as of 3:20 PM" when cached.

**Generator page - Parts tab.** The same ten cards, editable by roles above; "Used on N inspections" per item.

**Inventory (new top-level section, shown to all roles, with edit rights by role).** Tabs:
1. **Stock** - search, filter *low / out of stock*, category; tap a part for on-hand, reserved, available and recent movements.
2. **Job needs** - upcoming jobs with their lines and availability, grouped by date; Reserve / Issue actions.
3. **Shortages** - total missing per part across all jobs, ready to order.
4. **Catalog** - add or edit parts, alternate part numbers, minimum stock.
5. **Movements** - the ledger (admin and supervisor).

All of it reuses the existing components (section tabs, status chips, stat cards, empty states, skeletons) and the global search gains *Parts*.

## 8. Edge cases decided up front

* **Offline, two technicians use the same stock.** The ledger is append-only, so both entries sync; stock can briefly go negative and is flagged "needs reconciliation" for a supervisor instead of blocking either person.
* **Substitute parts.** A catalog part lists alternate part numbers; availability counts alternates, and the line shows "using alternate".
* **Part not in the catalog.** Allowed on the form; it is queued for an admin to add.
* **Same part on many generators.** One catalog row, many profile lines - changing a part number in the catalog updates its name everywhere.
* **Deleting.** Parts are deactivated, never deleted; movements are never edited, only offset by an adjustment.
* **Consumable fluids** (oil, coolant) are not in the ten slots, so they are not tracked as stock. See decision 5.

## 9. Delivery in four phases

| Phase | Delivers | Why this order |
|---|---|---|
| **A. Parts record** | The ten-slot Materials component with the four fields, in the inspection and maintenance forms; the generator Parts tab; Supabase tables for profile and job lines; PDF Materials table | Gives technicians the data entry immediately and needs no warehouse |
| **B. Catalog + stock** | Parts catalog, one warehouse, receive / adjust, the ledger, Stock and Catalog screens, part search in forms | Makes part numbers consistent and stock countable |
| **C. Job needs** | Needs lists from inspections, availability, reservations, issue / return, Job needs and Shortages screens, dashboard and search hooks | The "what's needed vs what's in the warehouse" system |
| **D. Extras** | Barcode / QR scan of part numbers, truck stock as extra locations, supplier and reorder history, usage reports | Worth doing once A-C are in use |

Each phase ships working on its own and is covered by tests (progress of the slot rules, the ledger arithmetic, availability and reservation, RLS checks per role).

## 10. Decisions needed from you

1. **What defines the parts a generator takes?** *Recommended:* a profile **per generator** (they differ even within one model), with one-tap copy from another generator of the same make and model. Alternative: one template per make/model with per-generator overrides.
2. **Warehouse model.** *Recommended:* one warehouse per company to start; the data model already allows several locations (including trucks) later.
3. **"Super admin."** *Recommended:* same as admin for now; add a cross-company `owner` role only if you will run several companies in the app.
4. **Who removes stock?** *Recommended:* the technician confirms what they used (stock drops), and the warehouse reconciles with a monthly count. Alternative: only warehouse staff issue stock.
5. **Fluids** (oil, coolant, fuel additives). *Recommended:* not tracked; the ten slots are filters and parts only.
6. **Batteries.** One battery slot as listed, or allow several (generators with two batteries)? *Recommended:* allow more than one, labelled by position.
7. **Scope of the form change.** The data entry belongs in the inspection form (what is installed, what is due) and the maintenance form (what was used). *Recommended:* one shared Materials component in both, so the data is entered once and never retyped.


## 11. Phase A - what was built

* **Ten-slot Materials editor** (`lib/modules/materials/`), one shared component used in the inspection form, the maintenance form and the generator profile. Each slot expands to its items; each item has part number, part name, manufacturer, quantity, date used (blank until set), notes, and on inspections a "needs replacement" switch. Fuel, oil and lube filters, batteries and additional parts take several items; the first three and batteries use Primary / Secondary (exactly one of each, enforced and tested), additional parts are a plain list.
* **Generator parts profile**, keyed by make + model + serial (case and spacing ignored). Reached from the Materials card ("Profile"), and from the equipment registry's asset page (inventory icon). Admins, supervisors and dispatchers edit it; technicians read it. A job's list can be filled with "Copy from generator profile", and "Save to profile" (editors only) updates the profile from a job.
* **Inspection form.** The Materials step now has the editor above a smaller "Service dates" card (last full service, coolant flush). The old oil / fuel / air / battery date fields are carried into the new items on first open and kept in step with them, so existing inspection PDFs and records read the same.
* **Maintenance form.** The Parts & Materials step has the editor; the older seven free-text boxes only appear on records that already have text in them. The step counts as done when parts are listed.
* **PDFs.** Maintenance reports print a "Parts & Materials Used" table (and the old free-text rows when present); inspection reports get a Parts & Materials page with a "Due" column.
* **Storage.** Autosaves to the device after typing pauses (adapter-free JSON store, like vehicle inspections) and queues changed rows for the cloud.
* **Database.** `supabase/migrations/20261106120000_materials_phase_a.sql` adds `asset_parts` (profile) and `job_material_lines` (job lists) with RLS: every tenant member reads; only admin / supervisor / dispatcher write profiles; any member writes their job lines. **It has to be run once in the Supabase SQL editor** (the automatic apply was declined). Until then parts save on the device and the cloud sync retries.
* **Tests.** Slot and list rules, storage and cloud-row mapping, the editor (adding, roles, quantity, date, profile copy, permissions, 1.3x text), PDF table.

## 12. Phase B - what was built

* **Parts catalog** (`lib/modules/inventory/`): part number, name, manufacturer, the slot it fits, unit, minimum stock, alternate part numbers, notes, active flag. Part numbers are compared ignoring case, spaces and punctuation ("AF-123" = "af 123"); duplicates are refused on the device and by a unique index in the database.
* **One warehouse per company** ("Main warehouse"; its id is the company id).
* **Append-only ledger.** Every receive, adjustment and count is a movement row; stock is the sum of a part's movements, so every number is traceable. A wrong entry is corrected with an offsetting adjustment. A count records the *difference* found. Reserve / release / issue / return are already allowed by the schema for Phase C. Offline entries can take stock below zero; that shows as "Needs recount" rather than blocking anyone.
* **Screens.** A new **Inventory** section (Stock, Parts Catalog). Stock shows Parts / Low / Out tiles, search, All / Low / Out filters, and a part sheet with on hand, reserved, available, minimum and history. **Only admins** see Receive stock, Adjust and Count and the catalog's Add / Edit; everyone else can look. (Documents moved into the Work section as a tab so the tablet rail stays at eight entries.)
* **Materials editor.** Typing a part number offers matching catalog parts (tap to fill number, name and manufacturer); an exact match shows "In stock: N" or "Not in stock".
* **Global search** finds parts by number, name, manufacturer or alternate.
* **Sync.** Changes queue like other records; opening Stock (or pulling down) fetches the cloud catalog and ledger (catalog by newest edit, movements added if missing).
* **Database.** `supabase/migrations/20261106180000_inventory_phase_b.sql` adds `parts_catalog`, `inventory_locations`, `inventory_movements` and the `inventory_stock` view; members read, admins write, no update or delete on movements. **Run it once in the Supabase SQL editor** after the Phase A file.
* **Tests.** Stock arithmetic for every reason, part search and matching, repository (duplicates, ledger, counts, tenant gating, cloud merge), Stock and Catalog pages with role gating, editor suggestions, navigation and route roles.

## 13. Phase C - what was built

* **Job needs.** Parts flagged "Needs replacement" on an inspection are the job's needs. Each is matched to the catalog by its part number or an alternate ("using alternate"), then checked against the ledger: *In stock*, *Partly in stock*, *Short*, *Reserved*, *Issued*, or *Not in catalog*. Stock already promised to other jobs is not counted as available.
* **Reserve, issue, return.** Reserve sets parts aside (on hand unchanged, available down); Issue takes the reserved quantity out of the warehouse; Release lets a reservation go; Return puts issued parts back. Each is a ledger movement tagged with the job (`inspection:ID`). Supervisors, dispatchers and admins do these; technicians can look.
* **Screens.** *Job Needs* (per job, soonest first, with the actions) and *Shortages* (what to order: per part the quantity jobs still need beyond what is available, parts missing from the catalog, and parts at or below their minimum) join Stock and Parts Catalog in the Inventory section.
* **Database.** `supabase/migrations/20261106200000_inventory_phase_c.sql` lets supervisors and dispatchers write job movements (reserve / release / issue / return, each naming its job). Receive, adjust and count stay admin-only. **Run it once in the SQL editor.**
* **Not yet:** the dashboard "parts short for N jobs" line, and needs from maintenance schedules (only inspection flags feed the list today).

## 14. Search

Global search is now a bottom sheet over the current page (a centred panel on tablets): a search field, filter chips with a count per kind (All, Pages, Inspections, ..., Parts), and grouped results.

## 15. Spreadsheet import (parts catalog and generator parts lists)

An admin can load parts from an Excel (`.xlsx`) or `.csv` file: **Inventory > Parts Catalog > Import**. The file is read on the device (`lib/modules/inventory/domain/import/`), cleaned, and shown in a preview. **Nothing is saved until the admin presses Import.**

**Two layouts are recognised**

| Layout | Looks like | Produces |
|---|---|---|
| Maintenance tracker | Heading row naming slots ("Air Filter", "Fuel Filter (Primary)"...), a sub-heading row with "Part Number / QTY Used / Date Used / Part Name", one row per generator, with Make / Model / Serial columns | Catalog parts **and** one generator parts list per identifiable generator (roles, quantities, manufacturer, date used) |
| Parts list | One part per row under headings such as Part Number, Description, Manufacturer, Min, Qty (on hand), Alternates | Catalog parts, minimums, alternates, optional opening stock |

Other sheets (free-text procurement notes, price quotes) are reported as "No part number columns recognised" and left alone.

**Cleaning rules**

* Invisible characters and odd spaces removed; part numbers upper-cased; `N/A`, `?`, `-`, `TBD`, `0` treated as blank.
* Excel damage fixed or flagged: `253108.0` becomes `253108`; scientific notation is warned about.
* Battery specs written differently (`8D-MHD CCA 1400 RC450`, `8D-MHD 1400 CCA RC 450`) become one part: `8D-MHD CCA 1400 RC 450`.
* Manufacturer spellings unified (`Detriot Diesel` becomes Detroit Diesel, `FleetGuard` becomes Fleetguard, `Racor/Parker` becomes Racor). A description in the name column ("Fuel Pump Asmbly") is kept as the part name, not the manufacturer.
* Repeats merged by part number ignoring case, spaces and punctuation. Warnings for a part listed under two manufacturers, used in more than one slot, written several ways, or containing a space (probable typo).
* Quantities and minimums read as whole numbers (negative or non-numeric ignored with a warning).
* An Excel date serial in a "Date Used" cell becomes a date; text such as `N/A` is ignored.

**Safe to re-run.** Parts already in the catalog are never overwritten; only blank fields (manufacturer, name, slot, minimum) are filled. Opening stock is recorded only for parts added by that import. A generator that already has a parts list is shown as "Has a list" and is not replaced. Rows left out (no part number, generator without make/model/serial, repeated generator) are listed with the reason.

**Preview.** Chips show new / to update / already there / left out / generators; views are All, Check (rows with warnings), New and Generators; every row can be unticked.

**First real run (2026-11-06).** `Shop Steward Procurement Tracker.xlsx` (Queens `Q_` and Bronx `X_` maintenance trackers): 163 parts and 50 generator parts lists (260 part lines) imported and synced. "Materials Tracking" (free text per site) and "Quote Comparison" were skipped; they would need a separate extraction.

Files: `sheet_reader.dart` (xlsx and csv reading; `archive` + `xml` packages), `parts_import.dart` (cleaning, parsing, merging, planning), `infra/parts_import_service.dart` (saving), `presenter/widgets/parts_import_sheet.dart` (picker and preview). Tests: `test/inventory/parts_import_test.dart` (including the real spreadsheet), `parts_import_sheet_test.dart`. `tool/inspect_xlsx.py` shows a sheet's layout before writing an import for it (see `docs/tools.md`).

## 16. Stock by manufacturer

The Stock page groups parts under headings with a count (`BALDWIN · 23`): **Group by Manufacturer** (default), **Type** (the material slot) or **None**. Spelling variants share one heading ("Donaldson" and "donaldson"), alphabetical, with "No manufacturer" last and parts in part-number order inside each group. A row of maker chips (All makers, Baldwin, Bosch...) filters to one manufacturer and combines with the All / Low / Out filters and the search box. When grouped, the row leaves out what the heading already says. Logic: `groupStock`, `manufacturersOf` in `domain/vendor.dart`. Tests: `test/inventory/vendor_pricing_test.dart` (grouping), `stock_grouping_page_test.dart`.

**Editing a part.** Admins tap a part in Stock to open its page, then **Edit part** (same editor as the catalog: number, name, manufacturer, slot, minimum, alternates, notes, active).

## 17. Vendors and prices

Prices are company costs, so everything here is **admin only** (Supabase policies and the app both enforce it; technicians, supervisors and dispatchers see no prices).

* **Vendors** (Inventory > Vendors): name, contact person, phone, email, our account number, notes, active flag. Duplicate names are refused (case and punctuation ignored), on the device and by a unique index.
* **Part prices.** From a part's page, **Add price**: vendor, price for one, Paid or Quote, the vendor's own part number, date, note. Entries are history: a new price is a new entry, the newest entry per vendor is that vendor's **current price**, and a wrong entry can be deleted. A part's page shows **Last paid** (most recent *paid* price, quotes excluded) and **Best** (lowest current vendor price, when more than one vendor has priced it).
* **Receiving with a price.** Receive stock has optional Vendor and Price-for-one fields; entering both records the receipt and the paid price together (a price without a vendor is refused).
* **Stock list.** Admins see "last $24.50" on each part and a **Shelf value** line (on hand x last price paid, with a count of parts that have no price yet).
* **Money** is stored as whole cents (`unit_price_cents`) so sums are exact; `parseCents` accepts `24.5`, `$1,234.50`, and rejects extra decimals.
* **Database.** `supabase/migrations/20261107090000_inventory_vendors_pricing.sql` adds `vendors` and `part_prices` (admin-only RLS, positive price check, kind `paid` / `quote`). **Applied.**
* Files: `domain/vendor.dart`, `infra/pricing_repository.dart`, `presenter/pages/vendors_page.dart`, `presenter/widgets/pricing_sheets.dart`. Route `inventory_vendors` is admin only.
* The vendor list is entered by hand (Vendors > Add vendor); a spreadsheet import for vendors can be added when the list arrives.

## 18. Phase C completed (2026-11-08)

The two "not yet" items from section 13 and three design items that were missing are now built.

* **Dashboard "Parts short for N jobs".** In Needs attention for dispatchers, supervisors and admins when N > 0 (N = jobs with any short, partial or not-in-catalog line); tap opens Shortages. Technicians never see it.
* **Needs from maintenance.** Open (not completed) maintenance records now feed Job Needs: every listed item that has a part number is a need (maintenance lists have no "needs replacement" switch). Completed maintenance is skipped; inspections still count only flagged items. Job ref stays `maintenance:ID`.
* **Movements screen** (Inventory > Movements; admin and supervisor). The ledger newest first, grouped by day: part, reason chip, signed quantity, note, job link (opens the inspection or maintenance), who. Filters: reason chips, Today / 7 days / 30 days / All (default 30 days), part search. Read-only; corrections stay as offsetting adjustments. Logic: `domain/movement_log.dart`.
* **"Used on N jobs"** on every item of the generator parts profile (each job counted once per part, matched by part number ignoring case and punctuation). `materials/domain/part_usage.dart`.
* **Technician "mark used" (decision 4).** On inspection and maintenance material items, **Mark used** records an `issue` movement for the item's quantity against the job: from the technician's assigned truck if it holds enough, otherwise the main warehouse. It sets the date used if blank, and is idempotent (`usedMovementId` on the item, so a second tap does nothing). **Undo** records a `return` at the original location. A part not in the catalog only records the date. Technicians may write issue / return movements for themselves (RLS in section 21).
* **Technician profile edits need approval (section 6).** Technicians keep read-only access to a generator's parts profile. They can **Propose a change** (the same editor on an in-memory copy; a reason is required) or **Propose to profile** from a job form; supervisors, dispatchers and admins keep "Save to profile". Reviewers use **Parts approvals** (Customers & Equipment section): pending requests with a per-item diff (added, changed old to new, removed); Approve all, Approve selected, Reject with a note. Changes that no longer match the profile are flagged *stale* and skipped unless forced. Approval saves through the normal profile save, so it syncs. Proposers see "Waiting for approval" with Withdraw and the last decisions. Files: `materials/domain/profile_change.dart`, `infra/profile_changes_repository.dart`, `presenter/profile_proposal_sheet.dart`, `pages/profile_approvals_page.dart`.

## 19. Phase D (built 2026-11-08)

* **Locations and truck stock.** The single warehouse became several locations (`inventory_locations.kind`: warehouse, truck, other). Admins add a truck on the Stock page (**Locations**), optionally linked to a fleet vehicle and an assigned technician. Stock page chips: All locations, Main warehouse, each truck; a part's page shows the per-location breakdown. `StockLevel` stays the company total.
* **Transfers.** **Transfer stock** on a part (admin, supervisor, dispatcher) moves a quantity between locations as two ledger rows with the new reason `transfer` (minus at the source, plus at the destination), so the company total never changes. A transfer that would take the source below zero is refused.
* **Purchase orders** (Inventory > Orders; admin only). From **Shortages**, "Create purchase orders" groups job shortages and below-minimum parts by each part's best current vendor (quantity = shortage, or minimum minus available), prefilling the vendor's price; parts with no price go under "No vendor yet" until a vendor is chosen. Each vendor's group saves as a draft PO (numbers PO-0001... per company, editable). A PO moves draft > sent > partial > received (or cancelled); **Receive** against a PO writes a `receive` movement noted with the PO number, records a paid price at the PO price, and updates the status. Receiving is idempotent per receive action; over-receiving is refused. A PO can be shared as text.
* **On order.** Shortages and low-stock rows show "On order N" and the quantity to order is net of open POs (a fully covered part shows "Covered"); a part's page shows "On order N" and its last five PO lines as **Reorder history** (admin only, because prices and orders are admin-only).
* **Barcode / QR for parts.** A Scan button (phones and tablets only) in the Stock search, the Catalog search and the Receive-stock part picker uses the same scanner as equipment search. An exact part number or alternate opens that part; an unknown code offers admins "Add this part" with the number filled in.
* **Usage reports.** A report sheet from the Movements header (admin and supervisor): quantity issued net of returns by part, manufacturer, month and generator, for 30 days / 90 days / 12 months / all time, with CSV export. Admins also see cost (issued quantity x last price paid). `domain/usage_report.dart`.

## 20. Roles at a glance

| | Technician | Dispatcher | Supervisor | Admin |
|---|---|---|---|---|
| Stock, Job Needs, Shortages, Catalog (look) | yes | yes | yes | yes |
| Reserve / release / issue / return for a job | no | yes | yes | yes |
| Mark used on their own job | yes | yes | yes | yes |
| Transfer stock between locations | no | yes | yes | yes |
| Receive, adjust, count, edit catalog, add trucks | no | no | no | yes |
| Movements and usage reports | no | no | yes | yes |
| Vendors, prices, purchase orders, shelf value, cost | no | no | no | yes |
| Edit a generator's parts profile | propose only | yes | yes | yes |
| Approve profile change requests | no | yes | yes | yes |

## 21. Database migrations

Run in the Supabase SQL editor, once each, in this order. Every file is idempotent.

| File | Adds | Status |
|---|---|---|
| `20261106120000_materials_phase_a.sql` | `asset_parts`, `job_material_lines` | applied |
| `20261106180000_inventory_phase_b.sql` | catalog, locations, ledger, stock view | applied |
| `20261106200000_inventory_phase_c.sql` | job movements for supervisors / dispatchers | applied |
| `20261107090000_inventory_vendors_pricing.sql` | `vendors`, `part_prices` (admin only) | applied |
| `20261108100000_purchase_orders.sql` | `purchase_orders`, `purchase_order_lines` (admin only) | **to run** |
| `20261108110000_truck_stock.sql` | location `vehicle_id` / `assigned_user_id`, `transfer` reason, per-location stock view, `used_movement_id` on job lines, technician issue / return policy | **to run before the app that sends `used_movement_id`** |
| `20261108120000_profile_change_requests.sql` | `profile_change_requests` and its policies | **to run** |

Known limits: "own truck first" is enforced in the app, not by the database (a technician can write issue / return for any location); removing an item already marked used does not reverse its issue (tap Undo first); a PO cannot have a line added after creation (edit or drop only); PO share is text only; profile approval is two steps (save, then mark approved), so a crash in between leaves the request pending and a second approve closes it as "already applied".

## 22. Part descriptions and product images

* **Description.** A part's stored field is still `name`; the app calls it **Description** (free text, 2-3 lines, up to 200 characters, e.g. "Fleetguard lube filter, spin-on, 4.5\" tall"). It is the subtitle on Catalog and Stock rows, body text on the part sheet, and is searched. The spreadsheet import no longer fills it with the slot label: it stays blank unless the sheet gives a real description. Admins can clear old generic names ("Air filter", "Battery"...) from **Parts Catalog > menu > Clean up generic names** (counts them, asks, then saves each part through the normal save so it syncs). Logic: `domain/generic_names.dart`.
* **Product image (optional, admin attaches, everyone views).** `CatalogPart.imagePath` holds the Storage object path `part-images/<tenant id>/<part id>.jpg` inside the existing private bucket `voltcore-files` (no new bucket or policy). In the part editor, **Add photo / Replace / Remove** uses the app's image picker at 1024 px max and JPEG quality 80. The file is cached at `part_images/<part id>.jpg` in the documents folder and uploaded through the file-upload outbox; the cloud row gets `parts_catalog.image_path`. Another device downloads the object on first view and caches it; any failure shows a placeholder, never an error. Shown as a wide tappable image (full-screen zoom) on the part sheet, a 48 px thumbnail on Catalog and Stock rows, and the editor preview. Code: `infra/part_image_store.dart` (`PartImageStore`, `PartImagePicker`, both injectable), `presenter/widgets/part_image.dart`.
* **Migration.** `20261110110000_part_images.sql` adds `parts_catalog.image_path` (idempotent). Run it before using photos; until then the cloud row sync of parts would fail if the column is missing, so run it first.
* **Limits.** Removing or replacing a photo does not delete the old object in Storage. A replaced photo keeps the same path, so other devices keep their cached copy until reinstall.
