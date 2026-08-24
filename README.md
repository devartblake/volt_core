# Voltcore

Voltcore is an offline-first Flutter field-service and compliance application.
It began with standby-generator inspections and maintenance and is evolving into
**Voltcore FieldOps**: tenant-safe customers, sites, assets, work orders,
scheduling, versioned inspection/maintenance templates, evidence, and signed
reports.

Flutter/Hive is the local execution layer. Supabase provides authenticated,
tenant-scoped synchronization and database authorization.

## Requirements

| Tool | Version |
| --- | --- |
| Flutter | stable channel; Dart SDK `^3.7.2` |
| Supabase | optional for local-only work; required for shared sync/RLS |

```bash
flutter doctor
flutter pub get
flutter run
```

For web:

```bash
flutter run -d edge
# or
flutter build web
```

## Configuration

Environment assets live in `assets/env/`:

- `.env.dev`
- `.env.staging`
- `.env.prod`

Each configured environment should provide:

```dotenv
SUPABASE_URL="https://<project>.supabase.co"
SUPABASE_ANON_KEY="<publishable key>"
SUPABASE_TENANT_ID="<public.tenants uuid>"
```

`SUPABASE_TENANT_ID` is a tenant UUID, never a user UUID. Authorization comes
from active `tenant_members` rows and database RLS. UI role checks are only an
affordance and cannot grant access the database refuses.

## Architecture

Feature-first clean architecture:

```text
lib/
├── app/                  router, shells, default-deny route RBAC
├── core/
│   ├── constants/        routes and feature flags
│   ├── services/         Hive, sync, storage, PDF, photos, notifications
│   └── theme/
├── modules/
│   └── <feature>/
│       ├── domain/
│       ├── infra/
│       ├── external/
│       └── presenter/
└── shared/widgets/
```

Key rules:

- **Offline first:** repositories persist locally before queuing cloud work.
- **Durable sync:** `SyncService` drains the Hive-backed outbox with retry.
- **Default-deny routing:** every named route needs an explicit `RouteRoles`
  decision; route tests fail closed when coverage is missing.
- **One page chrome:** screens use `AppPage`; shells own the app bar/navigation.
- **Web has no filesystem:** report/photo/signature bytes use `WebFileStore`
  (Hive/IndexedDB) instead of filesystem APIs.
- **Tenant authorization is server-owned:** Supabase RLS and tenant membership
  are authoritative.

## Testing and CI

```bash
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web
```

CI runs these gates for pull requests. A Phase 3 slice is not merged until the
analyzer, tests, and web build are green.

## Current FieldOps status — 24 August 2026

### Phase 1 — complete

- tenant-safe scheduling;
- generic asset vocabulary and registry support.

### Phase 2 — complete / rollout validation

- customer/site directory;
- site-aware asset registration/reassignment;
- QR lookup and asset history;
- work-order create/edit/list/detail and lifecycle controls;
- dispatch assignment/workload views;
- database-owned work-order events;
- schedule-task detail routing and inspection-to-maintenance handoff.

### Schedule deletion consistency

PR #52 fixed a race where a stale remote schedule GET could rehydrate a task
after its DELETE succeeded. Deleted task IDs are now tombstoned at the shared
schedule repository boundary, so the task stays absent from Upcoming, Dashboard
activity, statistics, calendar/list/timeline projections, and direct detail
until the same ID is intentionally saved again.

### Phase 3 — certification / pilot readiness

Merged capabilities include:

- tenant-safe versioned template/revision/field/response schema;
- atomic template draft save and publication;
- role-gated template management and draft editor;
- generic runtime renderer for text, number, reading, date, select, boolean,
  checklist, photo, and signature fields;
- visibility rules and response validation;
- local-first response autosave, restart recovery, and completion locking;
- exact-revision Hive definition cache;
- built-in generator inspection and maintenance template packs;
- lossless legacy generator adapters with `_legacyPayload` provenance;
- generic revision-pinned PDF renderer;
- native and web/IndexedDB report persistence;
- Documents discovery/open/share/delete on native and web;
- immutable report-artifact metadata linked to the completed response and its
  downstream customer/site/asset/work-order/inspection/maintenance context;
- technician field-form runtime at `/field-forms/:templateSlug`, guarded by a
  default-off build flag.

The report-artifact migration is deployed to the connected VoltCore Supabase
project and its RLS/trigger policies have been verified.

## Generator template pilot

The new execution path remains **off by default**. Enable it only in a controlled
pilot build:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

or:

```bash
flutter build web \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

Rollback is the inverse: omit the define or set it to `false`. The template
execution route disappears while the existing legacy inspection and maintenance
routes/reports remain intact.

Before starting a pilot, an authorized supervisor/dispatcher/admin should open
**Template Management** and use **Install generator templates**. The installer is
idempotent: existing tenant-owned slugs/revisions are not replaced.

Initial generator inspection pilot route:

```text
/field-forms/generator-inspection
```

Operational roles (technician, supervisor, dispatcher, admin) can execute
published field forms; template management remains restricted to supervisory
roles.

See [`docs/voltcore_fieldops_roadmap.md`](docs/voltcore_fieldops_roadmap.md) for
the final Phase 3 automated and manual certification checklist.

## Supabase setup

For a fresh installation use the consolidated schema and then apply later
migrations in timestamp order. Existing environments should apply only pending
migrations.

Core tenant bootstrap concept:

```sql
insert into public.tenants(name, slug)
values ('Your Company', 'your-company')
returning id;

insert into public.tenant_members(tenant_id, user_id, role)
values ('<tenant uuid>', '<auth.users uuid>', 'admin')
on conflict (tenant_id, user_id) do update
  set role = 'admin', is_active = true;
```

Never place service-role credentials in the Flutter application.

## Documents

Generated PDFs use the managed PDF tree on native platforms and logical `pdfs/`
paths in `WebFileStore` on web. The Documents screen reads both implementations
through the same metadata model.

## Documentation

| Document | Covers |
| --- | --- |
| `docs/voltcore_fieldops_roadmap.md` | FieldOps phases, Phase 3 implementation record, pilot/rollback certification |
| `docs/offline_sync_and_backup.md` | Durable sync and file backup |
| `docs/email_and_documents.md` | PDF library and report delivery |
| `docs/photos_reminders_and_reliability.md` | Photos, reminders, and file reliability |
| `docs/codebase_audit_and_ux_plan.md` | Broader codebase/UX audit and remediation plan |
