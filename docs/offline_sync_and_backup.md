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
| Inspections | `InspectionRepositoryImpl` | table `inspections` |
| Maintenance records | `MaintenanceRepo` + `MaintenanceRepositoryImpl` | table `maintenance_records` |
| Generated PDFs | `PdfService._saveAndMaybeEmailPdf` | Storage `pdfs/…` |
| Signature images | `FileStorageService` + inspection signature widget | Storage `signatures/…` |

## Required Supabase setup

The client is tolerant: if a table/bucket is missing, the operation simply stays
queued and retries — the app keeps working offline. To actually receive data,
create the following in the Supabase project.

1. **Storage bucket** — default name `voltcore-files` (override with
   `SUPABASE_STORAGE_BUCKET` in the env file). Add RLS policies allowing the
   authenticated technician to upload/read their files.

2. **Table `inspections`** — columns matching
   `InspectionRemoteDatasource.toSupabaseJson` (snake_case), primary key `id`.

3. **Table `maintenance_records`** — columns matching
   `maintenanceRecordToSupabaseJson` (snake_case), primary key `id`.

Because sync uses `upsert` keyed on `id`, primary keys must be the app-generated
UUID `id` column (not a DB-generated serial).

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
