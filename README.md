# Voltcore

Voltcore is an offline-first Flutter field-service and compliance application. It began with standby-generator inspections and maintenance and is evolving into **Voltcore FieldOps**: tenant-safe customers, sites, assets, work orders, scheduling, versioned inspection/maintenance templates, evidence, signed reports, fleet/operations tooling, and additional service verticals.

Flutter/Hive is the local execution layer. Supabase provides authenticated, tenant-scoped synchronization and database authorization.

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

`SUPABASE_TENANT_ID` is a tenant UUID, never a user UUID. Authorization comes from active `tenant_members` rows and database RLS. UI role checks are only an affordance and cannot grant access the database refuses.

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
- **Default-deny routing:** every named route needs an explicit `RouteRoles` decision; route tests fail closed when coverage is missing.
- **One page chrome:** screens use `AppPage`; shells own app navigation/chrome.
- **Web has no filesystem:** report/photo/signature bytes use `WebFileStore` (Hive/IndexedDB) rather than filesystem APIs.
- **Tenant authorization is server-owned:** Supabase RLS and `tenant_members` are authoritative.

## Testing and CI

```bash
flutter analyze --fatal-infos --fatal-warnings
flutter test
flutter build web
```

CI uses these gates for pull requests.

## Current FieldOps status — 3 September 2026

### Phase 1 — complete

- tenant-safe scheduling;
- generic asset vocabulary and registry support;
- local-first/durable-sync foundation.

### Phase 2 — complete / rollout validation

- customer/site directory;
- site-aware asset registration/reassignment;
- QR lookup and asset history;
- work-order lifecycle controls;
- dispatch assignment/workload views;
- database-owned work-order events;
- schedule-task detail routing and inspection-to-maintenance handoff;
- schedule-deletion tombstone repair so stale remote refreshes cannot resurrect deleted tasks.

### Phase 3 — automated implementation complete / manual pilot pending

Delivered capabilities include:

- tenant-safe versioned template/revision/field/response schema;
- atomic template draft save and publication;
- role-gated template management and draft editor;
- generic renderer for text, number, reading, date, select, boolean, checklist, photo, and signature;
- visibility rules and response validation;
- local-first autosave, restart recovery, completion locking, and exact-revision caching;
- built-in generator inspection and maintenance packs;
- lossless legacy generator adapters with `_legacyPayload` provenance;
- generic revision-pinned PDF rendering;
- native and web/IndexedDB report persistence;
- Documents discovery/open/share/delete;
- immutable report-artifact metadata and downstream links;
- technician runtime at `/field-forms/:templateSlug` behind a default-off pilot flag;
- Template Management discoverability;
- persisted app settings, change-password, export/cache controls;
- `tenant_members`-authoritative role administration and last-admin protection;
- tenant retention-policy configuration;
- privacy-aware advanced network logging and credential/query-secret redaction;
- safe unsaved-form navigation;
- stale queued-tenant healing;
- tenant-admin member/role management;
- inspection address normalization, explicit YES/NO presentation, and per-checklist-item conclusions.

The automated Phase 3 gates and database hardening are complete. The remaining Phase 3 gate is the controlled **A&S Electric generator pilot**.

## Generator template pilot

The template execution path remains **off by default**. Enable it only for a controlled pilot:

```bash
flutter run -d edge \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

or:

```bash
flutter build web \
  --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true
```

Rollback is the inverse: omit the define or set it to `false`. Legacy inspection/maintenance routes and reports remain available.

Before the pilot, an authorized supervisor/dispatcher/admin should open **Template Management** and use **Install generator templates**. Confirm:

- `generator-inspection`
- `generator-maintenance`

Pilot certification must cover online→offline work, restart recovery, exact-revision reopening, immutable completion, Documents/PDF generation, response/file sync, newer-revision compatibility, legacy-vs-template PDF parity, generator maintenance parity, and rollback with the build flag disabled.

See [`docs/voltcore_fieldops_roadmap.md`](docs/voltcore_fieldops_roadmap.md) for the concise roadmap and [`docs/voltcore_phase3_onward_and_retention_action_plan.md`](docs/voltcore_phase3_onward_and_retention_action_plan.md) for the detailed action plan and retention-enforcement design.

## Retention policy vs retention enforcement

Voltcore now stores tenant retention targets for archived maintenance and generated reports. Saving a policy is deliberately **non-destructive**.

Archive does not mean “safe to delete.” Destructive enforcement will be implemented separately as a staged evidence-lifecycle track:

1. eligibility/holds/dependency manifests/preview queue;
2. grace-period dry-run disposition;
3. certified idempotent purge beginning with archived maintenance jobs only.

Storage cleanup must succeed before destructive database cleanup, and every purge must leave a non-sensitive audit record.

## Supabase setup

For a fresh installation use the consolidated schema and then apply later migrations in timestamp order. Existing environments should apply only pending migrations.

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

Generated PDFs use the managed PDF tree on native platforms and logical `pdfs/` paths in `WebFileStore` on web. The Documents screen reads both implementations through the same metadata model.

## Documentation

| Document | Covers |
| --- | --- |
| `docs/voltcore_fieldops_roadmap.md` | Current FieldOps phases and Phase 3 pilot/rollback gate |
| `docs/voltcore_phase3_onward_and_retention_action_plan.md` | Detailed Phase 3 closeout, Phase 4–6 plan, retention enforcement |
| `docs/offline_sync_and_backup.md` | Durable sync and file backup |
| `docs/email_and_documents.md` | PDF library and report delivery |
| `docs/photos_reminders_and_reliability.md` | Photos, reminders, and file reliability |
| `docs/codebase_audit_and_ux_plan.md` | Historical codebase/UX audit snapshot; use the roadmap for current status |
