# Docs index

| Document | What it covers |
|---|---|
| [ui_ux_revamp_plan.md](ui_ux_revamp_plan.md) | The UI/UX revamp: audit, phases, what each sprint delivered, what is still open |
| [materials_and_inventory_design.md](materials_and_inventory_design.md) | Parts, stock, job needs, vendors and prices, purchase orders, truck stock, spreadsheet import, roles, and the SQL migrations to run |
| [generator_management_research.md](generator_management_research.md) | Features of other generator management systems, and which to borrow |
| [fleet_readiness.md](fleet_readiness.md) | Generator Fleet Readiness dashboard (generators, not the vehicle Fleet section): data and rules: sources, how records join to a generator, the status rules table, thresholds, API for the screens |
| [release_versioning.md](release_versioning.md) | How the app version is numbered, when to bump which part, the pilot and production stages, release steps |
| [branding.md](branding.md) | The Core Ring logo, its variants and usage rules, and the full light/dark colour palette with contrast ratios |
| [tools.md](tools.md) | How to use the scripts in `tool/` (xlsx inspector, UTF-8 scan, tablet and sign-in helpers, footer builder) |
| [remaining_tasks.md](remaining_tasks.md) | What is still open, decisions made, SQL to run, your tasks, bigger features and known gaps |
| [database_tables.md](database_tables.md) | Every Supabase table: what it holds, row counts, whether the app uses it, and what to do about the older ones |
| [offline_sync_and_backup.md](offline_sync_and_backup.md) | The offline queue, draining, the sync centre and offline banner |
| [email_and_documents.md](email_and_documents.md) | Server-side email and the Documents hub |
| [fleet_and_vehicle_assets_plan.md](fleet_and_vehicle_assets_plan.md) | Vehicles, vehicle assets, and the 2026-11-07 vehicle list / documents / PDF update |
| [photos_reminders_and_reliability.md](photos_reminders_and_reliability.md) | Photos, reminders and reliability work |
| [routing_audit.md](routing_audit.md) | Route conventions and fixes |
| [codebase_audit_and_ux_plan.md](codebase_audit_and_ux_plan.md) | The original codebase audit |
| [deferred_migrations_plan.md](deferred_migrations_plan.md) | Deferred code migrations (field widgets, colour tokens) |
| [voltcore_fieldops_roadmap.md](voltcore_fieldops_roadmap.md) | Product roadmap |
| [voltcore_phase3_onward_and_retention_action_plan.md](voltcore_phase3_onward_and_retention_action_plan.md) | Phase 3 onward plan |
| [phase3_pilot_certification_runbook.md](phase3_pilot_certification_runbook.md) | Pilot certification runbook |

Before committing: `python -I tool/utf8_scan.py`, `flutter analyze`, `flutter test`.
