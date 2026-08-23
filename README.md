# Voltcore

Field inspection and maintenance app for standby generator compliance work —
FDNY/DEP inspections, maintenance records, load tests, scheduling, and the PDF
reports that come out of them.

Built with Flutter, offline-first on Hive, syncing to Supabase when a
connection is available.

---

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | stable channel (Dart SDK ^3.7.2) |
| A Supabase project | for cloud sync (the app runs without one, locally only) |

Run `flutter doctor` before anything else.

## Getting started

```bash
flutter pub get
flutter run              # add -d chrome for web
```

Without Supabase configured the app still runs: everything saves to the local
Hive database, and sync operations queue up until credentials exist.

---

## Configuration

Environment files live in `assets/env/` and are **bundled as assets**, so a
change to one requires a rebuild — a hot reload or browser refresh keeps serving
the previous values.

| File | Used when |
| --- | --- |
| `assets/env/.env.dev` | default / debug builds |
| `assets/env/.env.staging` | staging |
| `assets/env/.env.prod` | release |

Keys each file should define:

```dotenv
SUPABASE_URL="https://<project>.supabase.co"
SUPABASE_ANON_KEY="<publishable key>"
SUPABASE_TENANT_ID="<uuid of a row in public.tenants>"
```

`SUPABASE_TENANT_ID` must be a **tenant** id, not a user id. Every synced row is
stamped with it, and row-level security rejects writes whose tenant the signed-in
user isn't a member of.

## Supabase setup

Run these in the SQL editor of your project, in order:

1. `supabase/schema/voltcore_complete_schema.sql` — tables, RLS policies, helpers.
2. `supabase/migrations/0002_align_app_sync_columns.sql`
3. `supabase/migrations/0003_missing_tables.sql` — `schedule_tasks`,
   `technicians`, `role_assignments`, and the dashboard RPC.
4. `supabase/migrations/0004_equipment.sql` — the shared equipment registry.

Then create a tenant and grant yourself membership — **roles come from the
database**, so without a `tenant_members` row the app treats you as a technician
regardless of what you pick at sign-in:

```sql
insert into public.tenants(name, slug)
values ('Your Company', 'your-company')
returning id;   -- put this uuid in SUPABASE_TENANT_ID

insert into public.tenant_members(tenant_id, user_id, role)
values ('<tenant uuid>', '<your auth.users uuid>', 'admin')
on conflict (tenant_id, user_id) do update
  set role = 'admin', is_active = true;
```

Storage bucket for signatures, photos, and PDFs:

```sql
insert into storage.buckets(id, name, public)
values ('voltcore-files', 'voltcore-files', false)
on conflict (id) do nothing;

create policy voltcore_files_rw on storage.objects
  for all to authenticated
  using (bucket_id = 'voltcore-files')
  with check (bucket_id = 'voltcore-files');
```

Verify the setup:

```sql
select exists(
  select 1 from public.tenant_members
  where tenant_id = '<SUPABASE_TENANT_ID>'
    and user_id = auth.uid()
    and is_active
) as writes_will_pass;
```

---

## Architecture

Feature-first, with clean-architecture layers inside each module:

```
lib/
├── app/            # router, shells, drawer, RBAC route table
├── core/
│   ├── services/   # hive, sync, storage, photos, pdf, notifications, forms
│   ├── theme/      # ColorScheme + StatusColors extension
│   └── constants/  # routes, feature flags
├── modules/        # inspections, maintenance, schedule, admin, auth, …
│   └── <feature>/
│       ├── domain/     # entities, usecases
│       ├── infra/      # models, mappers, repositories, datasources
│       ├── external/   # Supabase-facing implementations
│       └── presenter/  # pages, widgets, controllers
└── shared/widgets/ # AppPage + the component kit
```

Points worth knowing before changing things:

- **Offline-first.** Repositories write to Hive first, then enqueue a
  `SyncOperation`. `SyncService` drains that durable outbox with exponential
  backoff whenever connectivity allows; the UI never blocks on the network.
- **One page chrome.** Screens return `AppPage`, never their own
  `Scaffold`/`AppBar` — the shell owns navigation and the app bar. Adding a
  second `AppBar` reintroduces the doubled-header bug.
- **RBAC is default-deny.** Every route needs an entry in
  `lib/app/route_roles.dart`; unlisted routes are refused for all roles, and
  `test/app/route_roles_test.dart` fails if a `RouteNames` constant has no
  decision. Roles are read from `tenant_members` — the sign-in selector is only a
  preference and cannot escalate.
- **Web has no filesystem.** Signature and photo bytes go to `WebFileStore`
  (Hive/IndexedDB) instead of `dart:io`. Guard any new file work with `kIsWeb`.
- **Status colours** (`success` / `warning` / `info`) come from the
  `StatusColors` theme extension, not raw `Colors.green` — those don't adapt to
  dark mode.

## Testing

```bash
flutter analyze     # must stay clean; CI runs with --fatal-infos
flutter test
flutter build web   # or apk / ipa
```

CI (`.github/workflows/ci.yml`) runs analyze and the test suite on every push
and pull request.

## FieldOps delivery status

- **Phase 1 — complete:** tenant-safe scheduling and generic, site-aware asset
  foundation.
- **Phase 2 — core complete:** customer/site directory, site-aware asset
  registration and reassignment, QR lookup, asset history, and durable
  work-order lifecycle core. The dedicated work-order operations UI and
  production migration/RLS verification remain.

See [`docs/voltcore_fieldops_roadmap.md`](docs/voltcore_fieldops_roadmap.md)
for the completed-task record, deployment verification, and the remaining
Phase 2 gates.

## Documentation

Deeper notes live in [`docs/`](docs/):

| Document | Covers |
| --- | --- |
| `codebase_audit_and_ux_plan.md` | Full audit, findings, and the phased remediation plan |
| `deferred_migrations_plan.md` | Plan for the two deferred UI migrations |
| `offline_sync_and_backup.md` | Sync engine and cloud file backup |
| `photos_reminders_and_reliability.md` | Photo attachments, reminders, path handling |
| `email_and_documents.md` | Report email and the PDF library |
| `routing_audit.md` | Route table review (partly superseded by the audit doc) |
| `voltcore_fieldops_roadmap.md` | Expansion from generator compliance to field-service asset operations |
