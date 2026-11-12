# Volt Core: app tour and what has been updated

Volt Core is the A&S Electric app for generator inspections, maintenance, scheduling, vehicles and parts stock. It works offline on a tablet or phone and uploads to the cloud when it is back online.

- Version: **0.9.0+1** (see [release_versioning.md](release_versioning.md)).
- Theme: the **Core Ring** brand theme (navy, grey and white) in light and dark modes.
- Screenshots: taken on **2026-11-08** on the Samsung test tablet (portrait, 1320 x 2112), signed in as an admin, in light mode unless the section says dark. Pictures are reduced to 640 px wide.
- Test data only: this tablet holds a copy of the real generator inspections, a small parts catalog (163 parts, all at 0 on hand) and two trucks. Some screens are empty because that data does not exist yet. The pages say so where it happens.
- Privacy: the signed-in user's name, e-mail addresses, phone numbers, technician and driver names, vehicle plates and the Account card are covered with grey boxes in the pictures. Site codes, site addresses and generator makes and models are left in.

Roles used below: **tech** (technician), **dispatcher**, **supervisor**, **admin**. The role rules come from [lib/app/route_roles.dart](../lib/app/route_roles.dart) and section 20 of [materials_and_inventory_design.md](materials_and_inventory_design.md).

## What changed recently

From `git log`, [CHANGELOG.md](../CHANGELOG.md) and the design docs, newest first:

| When | Change |
|---|---|
| Latest | PDF footer shows the A&S Electric company logo in a pale colour; PDFs no longer use the app logo |
| Latest | Core Ring brand theme in light and dark, `AppLogo`, [branding.md](branding.md); new app icon, splash and store art |
| Latest | Database tables reference ([database_tables.md](database_tables.md)) and a follow-up foreign-key index migration |
| 2026-11-08 | Analytics: graphs on every small number card and on inspections, grades, jobs, maintenance, workload and parts |
| 2026-11-08 | Generator Fleet Readiness dashboard (new), later renamed, with a sideways attention row and card graphs |
| 2026-11-08 | Version 0.9.0+1: the app shows its real version; bump tool, changelog, versioning policy |
| 2026-11-08 | Inventory: part descriptions, product images, generic-name cleanup |
| 2026-11-08 | Inspections: finish rule, and delete limited to admins and dispatchers; new database policies |
| Earlier | UI revamp sprints 1 to 4: shared UI kit, navigation, dashboard, schedule, equipment, documents, fleet, maintenance, inspections, search, settings, login, sync centre |
| Earlier | Inventory and materials: spreadsheet import, vendors, purchase orders, truck stock, profile approvals |
| Earlier | Vehicle inspections, vehicle PDF, media gallery; branded PDF footer and maintenance PDF redesign |

---

## Home

### Dashboard

![Dashboard with the greeting hidden, today's counts, the generator readiness tile and Needs attention](images/app/01-home-dashboard.png)

The first screen after sign-in. It shows a greeting (name hidden here), five count cards (Today, Overdue, Open jobs, Inspections in 7 days, Generator fleet readiness) and a search box. All roles can open it. The Needs attention list is aimed at dispatchers, supervisors and admins.

![Dashboard scrolled: Needs attention, Today, Who is on what today, Quick actions](images/app/02-home-dashboard-needs-attention.png)

Scrolled: **Needs attention** (overdue tasks, generators not ready, vehicles without a daily check, red-grade sites, parts short for a job), **Today**, **Who is on what today** and **Quick actions**. Both Today cards are empty on the test tablet because nothing is scheduled for today.

Updated:

- A "Generator fleet readiness" tile and a "generators not ready" line in Needs attention ([ui_ux_revamp_plan.md](ui_ux_revamp_plan.md) section 11).
- Lines for vehicles without a daily check and for parts short for a job, seen in the screenshot.
- Rebuilt with the shared UI kit in the UI revamp sprints; new brand colours.

### Analytics

![Analytics: period selector, small cards with mini graphs, weekly bars, monthly line, grade donut](images/app/03-analytics-top.png)

![Analytics lower down: maintenance completion, maintenance records, schedule, workload and parts stock](images/app/04-analytics-lower.png)

Charts for the data on the device: inspections per week and per month, site grades, sites with most red grades, jobs, maintenance, schedule, workload and parts stock. A period selector (4 weeks, 12 weeks, 6 months, All) controls the time-based charts. All roles can open the page. The workload chart is for dispatchers and admins; stock charts are limited by role ([ui_ux_revamp_plan.md](ui_ux_revamp_plan.md) section 12).

Updated:

- Every small number card has its own mini graph (rings, strips, bars).
- New charts: inspections per week and month, site grades (tap a grade to open the list), jobs by status, maintenance records, technician workload, parts stock.
- "Sites with most red grades" now treats `b` and `B` as one site.
- "Jobs by status" shows "Not enough data yet" here because there are no jobs.

### Generator Fleet Readiness

![Generator Fleet Readiness overview: readiness donut, status cards, due by week, grade bar, needs-attention row, filters](images/app/05-fleet-readiness-overview.png)

![Generator Fleet Readiness unit list with status, last inspection grade and estimated due date](images/app/06-fleet-readiness-units.png)

One screen of every generator: ready, due soon, needs attention or not ready, with the reason. Top: a readiness donut and four status cards. Below: Due by week, Last inspection grade, a "Needs attention first" row, search, make and due filters, then the unit list. Because the generators have no next-due date, the screen counts 365 days from the last inspection and says "estimated". All roles can open it; technicians read only. Rules: [fleet_readiness.md](fleet_readiness.md).

Updated:

- New in 0.9.0: status rules, charts, filters, bulk scheduling, CSV and PDF export (the header icons).
- Renamed "Generator Fleet Readiness" so it is not confused with the vehicle Fleet section.
- Needs-attention row scrolls sideways; every number card has a small graph.
- The banner "6 records could not be matched to a generator" is a data note, not an error.
- Known gaps (not viewed on every device size, load-test dates inferred, session-only filters) are in [remaining_tasks.md](remaining_tasks.md) section E.

---

## Inspections

### Inspection list

![Inspections list with totals, grade filter chips, date chips and Not finished chips](images/app/07-inspections-list.png)

All inspections, newest first, grouped by date. Top: Total, Pending, Amber and Red counts. Then search (address, site code, technician), filter chips (Green, Amber, Red, This week, Needs follow-up) and date chips (All, Today, This week, This month, Pick a date). Each row has a grade chip and a **Finished / Not finished** chip; every row visible here says Not finished. The **Pending Reviews** tab is for supervisors, dispatchers and admins. All roles can start a new inspection. Only **admins and dispatchers** can delete one.

Updated:

- Finish rule: finished only when the post-inspection checklist is at least 50% done and the five required parts (air, fuel, oil or lube and coolant filters, battery) each have a part number. Saving a draft is always allowed.
- Saved filter presets, Green / Amber / Red chips, search box, swipe actions, density toggle (0.9.0 changelog).
- Delete limited to admins and dispatchers, in the app and in a new database policy.

### Inspection detail

![Inspection detail: status, missing part numbers, grade, schedule buttons and PDF preview](images/app/08-inspection-detail.png)

Read-only view of one inspection (nothing was changed to take this picture). It shows the status, what is missing for the finish rule ("Missing part number: Air filter" and so on), the grade, **Schedule This Inspection** and **Schedule Maintenance**, and a preview of the PDF with print and share. The technician name and the company contact line in the PDF preview are covered.

Updated:

- The "Not finished" line lists what is missing, from the new finish rule.
- Every share, export, print and email action now reports a failure in plain language.

---

## Work

The Work section has five tabs: Jobs, Maintenance, Schedule, Archive and Documents. All roles see Jobs, Maintenance, Schedule and Documents. **Archive** is for supervisors, dispatchers and admins (not pictured).

### Jobs

![Jobs: empty list with counts and Create job](images/app/09-jobs.png)

Work orders with counts (Open, Due today, Overdue, Unassigned), search and status and priority filters. The list is empty on the test tablet: there are no work orders yet, only one scheduled task, which shows on Schedule until it becomes a work order.

Updated: the list builds lazily so a long list stays fast ([ui_ux_revamp_plan.md](ui_ux_revamp_plan.md) section 10).

### Maintenance

![Maintenance list with Completed and In progress cards and PDF, print, schedule and delete buttons](images/app/10-maintenance.png)

Generator maintenance records, with filters All, In progress and Completed. Each card has the site code, status, hours, site, generator, and buttons for PDF, print, schedule and delete. Technician names are covered here.

Updated:

- "In progress - 3 of 8" shows how many steps are done.
- A "Not uploaded yet" badge appears on a card until the record reaches the cloud.
- Maintenance PDF redesigned, with the branded footer.

### Schedule

![Schedule in Month view with counts and a calendar](images/app/11-schedule-month.png)

![Schedule in Week view with one scheduled inspection and an Assign button](images/app/12-schedule-week.png)

Scheduled inspections and maintenance in **Day, Week or Month** view, with All or Unassigned filters. The Week view shows one scheduled inspection (site X460, unassigned). I also switched to Day view; it is not pictured. Dispatchers, supervisors and admins can assign a task; technicians cannot.

Updated:

- Day, Week and Month views (Month is the default and the choice is kept for the session).
- One shared job card; technician filter chips; tap-to-assign, with an Unassigned option that clears the assignee in the cloud too (fixed in 0.9.0).

### Documents

![Documents hub with type chips, search, sort and a list of PDFs](images/app/13-documents.png)

The one place for every generated PDF: search, type chips with counts (All, Inspections, Maintenance, Vehicles, Other), sort, date groups. Each file can be opened, printed, shared or e-mailed. The tablet holds 62 documents (33.2 MB). All roles can open it; it is also reachable from Settings.

Updated:

- New hub with Undo on delete, multi-select, and a "Clear old files" action (older than 90 days, asks first). See [email_and_documents.md](email_and_documents.md).
- The Generator Fleet Readiness PDF appears under Other (a type filter for it is not built yet).

---

## Fleet

Vehicles, their daily checks and their tools. Not to be confused with Generator Fleet Readiness in Home.

### Vehicles

![Vehicles list with two trucks, status chips and Daily check overdue chips](images/app/14-vehicles.png)

The company trucks with status, odometer and a **Daily check** chip (done today, due, overdue). Plates are covered. Supervisors, dispatchers and admins can add or edit a vehicle. A vehicle opens to six tabs: Overview, Inspections, Maintenance, Media, Documents, Tools (not pictured).

Updated:

- Daily check chip on every card; vehicle PDF now includes signatures and photos ([fleet_and_vehicle_assets_plan.md](fleet_and_vehicle_assets_plan.md)).

### Inspection Log

![Vehicle inspection log grouped by truck, with daily inspections](images/app/15-vehicle-inspection-log.png)

Daily, weekly and monthly walk-around inspections, grouped by truck, with filters for date and type. Driver names are covered. All roles can see it; reads are limited to managers, the inspector and the vehicle's assigned user.

Updated:

- Vehicle inspections now upload to the cloud and show "Not uploaded yet" until sent.
- Reads are restricted as described above (new database policy, applied 2026-11-08).

### Tool Catalog

![Tool Catalog: empty, with Add tool](images/app/16-tool-catalog.png)

The list of tool types that vans carry. Admin only. It is empty on the test tablet: no tools are catalogued yet.

---

## Customers & Equipment

### Customers & Sites

![Customers and sites: empty directory with Add customer and Add site](images/app/17-customers-and-sites.png)

The customer and site directory. It is empty on the test tablet. All roles can open it. The section also has an Asset Search tab (not pictured).

### Equipment

![Equipment list of site addresses with site codes and Edit Data](images/app/18-equipment.png)

The generator records, one row per site with its last date and site code, and an **Edit Data** button. On wide tablets the equipment search page uses a two-pane layout and a scan button on phones (UI revamp sprint 4; not shown here).

Updated: equipment search got recent searches, a two-pane tablet layout and a barcode and QR scan on Android and iOS.

### Parts approvals

![Parts approvals: nothing waiting](images/app/19-parts-approvals.png)

Technicians can propose a change to a generator's parts profile; dispatchers, supervisors and admins approve or reject it here. Nothing is waiting on the test tablet. New in 0.9.0.

---

## Inventory

Tabs: Stock, Job Needs, Shortages, Parts Catalog, Orders, Vendors, Movements. Who sees what ([materials_and_inventory_design.md](materials_and_inventory_design.md) section 20):

| | Tech | Dispatcher | Supervisor | Admin |
|---|---|---|---|---|
| Stock, Job Needs, Shortages, Parts Catalog (look) | yes | yes | yes | yes |
| Reserve, release, issue, return for a job | no | yes | yes | yes |
| Transfer stock | no | yes | yes | yes |
| Receive, adjust, count, edit catalog | no | no | no | yes |
| Movements | no | no | yes | yes |
| Vendors, prices, orders | no | no | no | yes |

### Stock

![Stock grouped by manufacturer with counts, filters and maker chips](images/app/20-stock.png)

Every part with on-hand count, grouped by manufacturer (here BALDWIN with 23 parts). Cards show Parts, Low and Out; filters are All, Low and Out of stock; Group by None, Manufacturer or Type; maker chips narrow the list. All 163 parts show "Out of stock" because opening counts have not been entered.

![Part sheet with on hand, reserved, available, minimum and action buttons](images/app/21-stock-part-sheet.png)

Tapping a part opens its sheet (opened and closed only): on hand, reserved, available, minimum, then Transfer stock, Edit part, Add price, Receive stock, Adjust and Count, then History. Nothing was changed.

Updated:

- Grouping by manufacturer, with spelling variants joined.
- Part descriptions, product images, and a "clean up generic names" action.
- Stock, Catalog and Vendors build lazily.

### Job Needs

![Job Needs: one inspection with five parts, three short and two not in catalog](images/app/22-job-needs.png)

For each job or inspection, the parts it needs and whether the warehouse can cover them: **Short**, or **Not in catalog**. Here one inspection needs five parts.

### Shortages

![Shortages: totals and the parts to order](images/app/23-shortages.png)

The parts short for jobs, with how many to order. The **Create purchase orders** button (admin) was not used. Technicians can look but not order.

### Parts Catalog

![Parts Catalog list with part number, type, manufacturer and Import button](images/app/24-parts-catalog.png)

The catalog of part numbers. Admins can add a part or import a spreadsheet (the Import button was not used).

Updated: spreadsheet import with cleaning, plus part descriptions and photos.

### Orders

![Orders: filter chips and one draft purchase order](images/app/25-orders.png)

Purchase orders, admin only. There is one draft order on the test tablet. Share is text only, and a line cannot be added after the order is created ([remaining_tasks.md](remaining_tasks.md) section E).

### Vendors

![Vendors: one vendor with the contact line hidden](images/app/26-vendors.png)

Vendors and their prices, admin only. The contact name and phone are covered.

### Movements

![Movements: empty ledger with date and type filters](images/app/27-movements.png)

The stock ledger: receipts, adjustments, counts, reservations, releases, issues, returns and transfers, with usage reports. Supervisors and admins only. It is empty because no stock has moved yet.

Updated: shows 50 rows at a time with "Show more".

---

## Settings

All roles can open Settings. It has three tabs: Settings, Configuration and About.

### Settings

![Settings scrolled: Appearance, Notifications, Data and Sync](images/app/28-settings-appearance-and-sync.png)

This picture is scrolled so the Account card (name and e-mail) is not shown. **Appearance** has the Dark Mode switch, "Bottom navigation on tablets", Language and Date Format. **Data & Sync** has Auto-Sync, Sync centre, Documents, Clear Cache and Export Data.

![Settings scrolled further: PDF and Advanced groups](images/app/29-settings-pdf-advanced-about.png)

**PDF** has the inspection template (Standard) and an optional closing summary page. **Advanced** has Template Management, Selection Options and Debug Tools. **About** shows the version, 0.9.0 (1).

Updated:

- Settings regrouped into Account, Appearance, Notifications, Data & Sync, PDF, Advanced and About.
- Sync centre entry, bottom navigation option for tablets, PDF summary page option.
- The version shown is the real one (0.9.0 (1)).

### Configuration

![Configuration: Technicians, Generator Makes and Voltage Ratings lists, all empty](images/app/30-settings-configuration.png)

Pick lists used by the forms: Technicians, Generator Makes, Voltage Ratings. All three are empty on the test tablet.

### About

![About: logo, version, key features, website and credits](images/app/31-about.png)

Logo, version and a short description. The support e-mail address is covered. The page still carries the 2024 copyright line.

---

## Admin

Admin only.

### Overview

![Admin Overview: total inspections, open maintenance jobs, active technicians and a link to manage roles](images/app/32-admin-overview.png)

Three counts (inspections, open maintenance jobs, active technicians) and a link to manage technicians and roles. Tabs: Admin Overview, Technicians, Tenants and Admin Settings.

### Technicians

![Technicians: member list with roles; names and e-mails hidden](images/app/33-admin-technicians.png)

The team: each member has a role (admin, dispatcher, supervisor, tech) that an admin can change. Names and e-mails are covered. An **Add member** button is present. Inviting by e-mail is in progress (see below).

### Admin Settings

![Admin Settings: advanced logging, data retention policy, team roles](images/app/34-admin-settings.png)

Advanced logging switch, Data retention policy and Team roles & permissions. The Tenants tab was not captured.

---

## Light and dark theme

Settings > Appearance > Dark Mode switches the whole app. The pictures below are the same screens in dark mode. Both themes use the palette in [branding.md](branding.md); contrast is checked by tests ([ui_ux_revamp_plan.md](ui_ux_revamp_plan.md) section 9). Signature pads stay white paper in both themes on purpose.

![Dark dashboard](images/app/35-dark-dashboard.png)

![Dark Generator Fleet Readiness](images/app/36-dark-fleet-readiness.png)

![Dark Analytics](images/app/37-dark-analytics.png)

![Dark Stock](images/app/38-dark-stock.png)

The tablet was switched back to light mode after these pictures.

## Search and sync

![Global search sheet with page shortcuts](images/app/39-search-sheet.png)

The magnifier at the top right opens a search sheet. With nothing typed it lists the main pages (Dashboard, Analytics, Generator Fleet Readiness, Inspections, Pending Reviews, Jobs, Maintenance, Schedule). Typing searches jobs, equipment, vehicles and parts. The on-screen keyboard is cropped out.

![Sync centre sheet: last synced, Sync now, everything uploaded](images/app/40-sync-centre-sheet.png)

The cloud icon opens the sync centre: last sync time, a **Sync now** button, anything waiting to upload, and failed items with Retry. Here it says "Everything is uploaded". An offline banner appears under the app bar when the device is offline with changes waiting ([offline_sync_and_backup.md](offline_sync_and_backup.md)). The large-upload stall (about 100 queued changes) was fixed in 0.9.0.

## Branding

The logo is **B. Core Ring**: a navy disc, a grey ring, a white core and a navy lightning bolt.

| Light surfaces | Dark surfaces |
|---|---|
| ![Core Ring logo, light variant](images/app/brand-logo-light.png) | ![Core Ring logo, dark variant](images/app/brand-logo-dark.png) |

Files are in `assets/brand/`. In the app, use the `AppLogo` widget, which picks the right variant.

The four concepts that were compared (A bolt tile, B core ring, C layered V, D pulse hex); B was chosen:

![Logo concept sheet](images/app/brand-logo-concepts.png)

The app icon uses the dark variant on a deep-navy tile (legacy, adaptive and Android 13 monochrome versions). Details: [branding_launcher_icon.md](branding_launcher_icon.md).

![App icon preview](images/app/brand-icon-preview.png)

Palette (full table with contrast ratios in [branding.md](branding.md)):

| Name | Hex |
|---|---|
| Brand navy | `#103078` |
| Deep navy | `#0A1F4D` |
| Grey 700 | `#4B5363` |
| Grey 500 | `#8B93A1` |
| Grey 300 | `#C9CED6` |
| White | `#FFFFFF` |
| Pale navy (dark logo disc) | `#E4E9F3` |

Source of truth: `lib/core/theme/brand_palette.dart`. The app bar is navy with white content in light mode.

## PDF reports

![PDF footer with the pale A&S Electric company logo before the company name](images/pdf-footer.png)

The PDF footer is a navy band with the A&S Electric company logo in a pale ice blue, then the company name, report title, site and page number. **The app logo is not used in any PDF.** There are PDFs for inspections, maintenance, vehicles and the Generator Fleet Readiness report. In Settings you can choose the inspection template and add a closing summary page.

## Behind the scenes

Work in the database and the code under the screens. States come from [remaining_tasks.md](remaining_tasks.md) and the design docs.

| Item | State | Doc |
|---|---|---|
| Housekeeping policies and indexes (vehicle inspection reads, policy speed-ups, 17 foreign-key indexes) | Applied 2026-11-08 and checked | [remaining_tasks.md](remaining_tasks.md) section B |
| Inspection delete policy (admins and dispatchers) | Applied 2026-11-08 and checked | [remaining_tasks.md](remaining_tasks.md) section B |
| Part images column | Applied 2026-11-08 and checked | [remaining_tasks.md](remaining_tasks.md) section B |
| Two extra foreign-key indexes (`20261110130000_fk_index_fixes.sql`) | Listed as "to run" | [remaining_tasks.md](remaining_tasks.md) section B |
| Inventory, vendors, orders, truck stock and approvals tables | See the migration table | [materials_and_inventory_design.md](materials_and_inventory_design.md) section 21 |
| Supabase advisors review (security and speed) | Done; findings and what was left alone are listed | [remaining_tasks.md](remaining_tasks.md) section F |
| Every Supabase table described, with an older-table review | Done | [database_tables.md](database_tables.md) |
| Version numbering, bump tool, release steps | Done | [release_versioning.md](release_versioning.md) |
| Scripts in `tool/` (tablet driver, UTF-8 scan, footer builder) | Done | [tools.md](tools.md) |
| Offline queue, sync centre, 100-item stall fix | Done | [offline_sync_and_backup.md](offline_sync_and_backup.md) |

### In progress

Other work is being built right now and is **not finished**. None of it is part of the pictures above.

- Purchase order numbers issued by the server.
- Approving a profile change as one atomic step (today it is two steps).
- A guard against stale writes (an old copy overwriting newer data).
- Nightly retention cleanup and a daily summary e-mail (server functions; they are not live until deployed and scheduled).
- Inviting a technician by e-mail from the Technicians page.
- An audit log page: who deleted or changed inspections, prices, vendors, orders, stock and roles.
- Job cost: the parts cost of each job at the last price paid.

## Still open

Summary of [remaining_tasks.md](remaining_tasks.md):

- **Your data tasks:** enter opening stock counts, minimums, vendors and prices; finish the spreadsheet import (three generators, Q313, Q680 and Q419, have no make, model or serial); replace generic part names with descriptions; save one real vehicle inspection to confirm upload end to end.
- **BusyBusy:** ask what its API and Zapier actions allow before deciding any integration.
- **Security:** turn on leaked-password protection in Supabase and rotate the two passwords that appeared in an earlier chat; fill in the technician sign-in for testing.
- **Database:** run `20261110130000_fk_index_fixes.sql`; tighten `inspections_update` (any tenant member can update any inspection) and review six callable functions.
- **Bigger features not started:** compliance calendar (check intervals against NFPA 110 first), run-hour maintenance triggers, remote monitoring (not recommended unless customers ask), BusyBusy integration.
- **Known gaps:** "own truck first" is enforced in the app only; removing an item already marked used does not reverse its stock; purchase orders cannot gain a line after creation and share is text only; vehicle inspection files on a second device point at the first device's paths; the dev sign-in code is gated only by the build flag; several screens were still unchecked on a tablet when that list was written (section E there); Documents and inspection lists are not paged.
- **Housekeeping:** the PDF export test was flaky in the full suite and needs confirming; nothing has been pushed to GitHub.
