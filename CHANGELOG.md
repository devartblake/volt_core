# Changelog

All notable changes to Volt Core, newest first. The version number format and
when to change it are described in [docs/release_versioning.md](docs/release_versioning.md).
Add a line under **Unreleased** with every change worth telling a user about;
`python -I tool/bump_version.py` moves those lines under the new version.

## [Unreleased]

### Added

- Admins can override what one person may do: Technicians, Permissions. Each of 13 permissions (sign off work, delete records, manage inventory, assign schedule and more) is Role default, Allow or Deny; the app enforces it, database access still follows the role
- A person can belong to more than one division (pick several on Technicians and in the Invite sheet; Settings, Account lists them all)
- New Apprentice role: works like a technician but cannot sign off, complete or delete work (signatures, Job Completed, Complete, Mark completed, deleting records and reports); shows "A technician or supervisor needs to sign this off."
- Divisions: admins keep a company list (Admin settings, Divisions) and give each person any number; shown on Technicians, in the Invite sheet and under Settings, Account
- Admin audit log: who deleted or changed inspections, prices, vendors, orders, stock adjustments and team roles
- Admins see the parts cost of each job (at the last price paid) on Job Needs
- Admins can invite new users by email
- Nightly retention cleanup and daily summary email (server functions)

### Changed

- New Core Ring logo and navy/grey/white colour theme, with matching light and dark modes (`docs/branding.md`)
- PDF footer shows the A&S Electric company logo (pale, on the navy band) before the company name; PDFs do not use the app logo

### Changed
- New app icon and splash screen.

## [0.9.0] - 2026-11-08

### Added
- Generator Fleet Readiness dashboard: which generators are ready, due soon, need attention or are not ready, with reasons, charts, filters, bulk scheduling and CSV / PDF export.
- Inventory: parts catalog, stock grouped by manufacturer, spreadsheet import with cleaning, vendors and prices, purchase orders, truck stock and transfers, movements and usage reports, part photos and descriptions, parts barcode scan.
- Technician profile edit proposals with a Parts approvals page for reviewers.
- Schedule day / week / month views, technician filter and assign; Documents hub with undo and multi-select; sync centre, offline banner and "Not uploaded yet" badges.
- Inspections: finish rule (checklist at least 50% plus the five required parts), filter presets, swipe actions, density toggle.
- Vehicle inspections now upload to the cloud.
- The app shows its real version in Settings and About.

### Changed
- Settings regrouped; login page rebuilt with validation; signature pads use a theme-independent paper surface.
- Inspections can be deleted by admins and dispatchers only.
- Every share, export, print and email action reports failures in plain language.

### Fixed
- Large uploads no longer stop after about 100 queued changes.
- Unassigning a task now clears the assignee in the cloud.

