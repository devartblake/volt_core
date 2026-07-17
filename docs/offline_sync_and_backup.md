# Offline-first sync & cloud file backup

Voltcore is offline-first: every create/update/delete is written to local Hive
**first** and never blocks on the network. A durable outbox then pushes those
changes to Supabase whenever the device is online. Generated PDFs and signature
images are backed up to Supabase Storage through the same queue.

## How it works

```
Repository / save site
        │  (local Hive write = source of truth)
        ▼
SyncService.enqueue*  ──►  SyncQueue (Hive Box<String> of JSON ops)
        │                         ▲
        │                         │ persists across app restarts
        ▼                         │
   drain when online  ──►  Supabase (Postgres tables + Storage bucket)
```

- **`SyncQueue`** (`lib/core/services/sync/sync_queue.dart`) — a plain
  `Box<String>` outbox. It stores operations as JSON, so it needs **no Hive
  adapter / code generation** and can't collide with model typeIds. Repeated
  edits to the same entity collapse into one pending op (latest wins).
- **`SyncOperation`** — one queued unit: `upsert`, `delete`, or `fileUpload`.
- **`ConnectivityService`** — wraps `connectivity_plus`; emits online/offline.
- **`SyncService`** (`lib/core/services/sync/sync_service.dart`) — drains the
  queue with exponential backoff (capped at 5 min) and a retry budget (8
  attempts, after which an op is marked `failed` and kept for manual retry). It
  exposes a `ValueNotifier<SyncStatus>` for the UI and re-drains automatically
  when connectivity returns. It never throws, so it can't break startup.
- **`FileBackupService`** — uploads a local file's bytes to Supabase Storage.

Initialization happens in `initCoreServices()` after Supabase is ready.

## What gets synced

| Data | Where it's queued | Supabase target |
| --- | --- | --- |
| Inspections | `InspectionRepositoryImpl` | table `inspections` (identity cols + `payload` jsonb) |
| Maintenance | `MaintenanceRepo` + `MaintenanceRepositoryImpl` | tables `maintenance_jobs` (identity) + `maintenance_records` (`data` jsonb) |
| Generated PDFs | `PdfService._saveAndMaybeEmailPdf` | Storage `pdfs/…` |
| Signature images | `FileStorageService` + inspection signature widget | Storage `signatures/…` |
| Photos | `PhotoService` | Storage `photos/…` |

The serializers match the consolidated v2 schema (jsonb payloads), not flat
columns:

- **`inspections`** — `InspectionRemoteDatasource.toSupabaseJson` writes identity
  columns (`id`, `tenant_id`, `site_code`, `site_grade`, `address`,
  `service_date`, `technician_name`, `notes`, `pdf_path`, timestamps) plus all
  detail fields under the `payload` jsonb column.
- **Maintenance** — each save writes two rows keyed by the record id
  (`maintenance_supabase_mapper.dart`): a `maintenance_jobs` identity row and a
  `maintenance_records` row whose `data` jsonb holds the full detail
  (`job_id == record id`). Delete targets the job and cascades.

## Required Supabase setup

**One-file option:** run `supabase/schema/voltcore_complete_schema.sql` — a
single, idempotent, app-aligned superset of the v2 schema that already includes
the `voltcore-files` bucket, the missing `maintenance_records`/detail-table RLS
policies, storage policies, and a bootstrap/seed template. Running it is
equivalent to steps 1–2 below plus the policy gaps.

The client is tolerant: if a table/bucket is missing, the operation stays queued
and retries — the app keeps working offline. To receive data:

1. **Run the v2 schema** (`voltcore_supabase_consolidated_schema_v2.sql`) — it
   creates `inspections`, `maintenance_jobs`, `maintenance_records`, RLS, and
   helper functions.

2. **Run `supabase/migrations/0002_align_app_sync_columns.sql`** — creates the
   `voltcore-files` storage bucket and documents the tenant/RLS/storage-policy
   follow-ups.

3. **Configure the tenant** — set `SUPABASE_TENANT_ID` (env) to a real
   `public.tenants.id` UUID, and add the signed-in user to `tenant_members`, or
   RLS + the NOT NULL `tenant_id` will reject writes. See `SyncContext`.

4. **Add `maintenance_records` RLS + storage policies** (the v2 file doesn't
   include them) — sample SQL is in migration `0002`.

Sync `upsert`s on the primary key `id` (the app-generated UUID), so keep `id` as
the PK on each table.

## Using the status indicator

Drop `SyncStatusIndicator` into an app bar to show live sync state (offline /
syncing / pending / failed / synced). Tapping it forces a sync (and retries
failed ops):

```dart
AppBar(
  actions: const [SyncStatusIndicator()],
)
```

## Conflict handling

The current policy is last-write-wins (the most recent upsert overwrites the
row). That's appropriate for single-technician-per-record workflows. If records
become concurrently editable, add an `updated_at` guard on the server or a
merge step in `SyncService._dispatch`.

## Notes / follow-ups

- Sync is currently **push-only** (local → cloud). Pull/merge from the cloud can
  reuse the existing `fetchInspections()` remote datasource.
- The queue drains on connectivity changes and on each enqueue. For long
  background windows, consider `workmanager` for periodic drains.
