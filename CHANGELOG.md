# Changelog

All notable changes to Volt Core, newest first. The version number format and
when to change it are described in [docs/release_versioning.md](docs/release_versioning.md).
Add a line under **Unreleased** with every change worth telling a user about;
`python -I tool/bump_version.py` moves those lines under the new version.

## [Unreleased]

### Changed

- New Core Ring logo and navy/grey/white colour theme, with matching light and dark modes (`docs/branding.md`)
- PDF footer shows the app logo before the company name

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

