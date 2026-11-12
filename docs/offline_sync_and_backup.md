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
syncing / pending / failed / synced). Tapping it opens the **sync centre**
(see below):

```dart
AppBar(
  actions: const [SyncStatusIndicator()],
)
```

## Conflict handling

Most tables are still last-write-wins by arrival time (the most recent upsert
overwrites the row), which suits single-technician-per-record work.

**Newer wins by `updated_at` for six tables** (migration
`20261111120000_stale_write_guard.sql`): `parts_catalog`, `inventory_locations`,
`vendors`, `purchase_orders`, `profile_change_requests`, `vehicle_inspections`.
The app upserts these with a client `updated_at`; `set_updated_at()` then
overwrites it with the server time, so the stored value is when the server last
accepted a change. The `trg_00_reject_stale` trigger (it sorts before
`trg_*_updated_at`) compares the incoming client time with the stored one and,
when the edit is more than a 2 minute grace older, skips that row's update and
raises a notice. For an upsert that is a quiet success, so the queue drops the
operation instead of retrying it forever. The grace stops two quick edits from
one device racing their own latency; a device clock wrong by more than the grace
can lose edits after another write to the same row (a `client_updated_at`
column would fix that).

Not guarded: append-only ledgers (`stock_movements`, `part_prices`), tables where
`updated_at` is server-only (`asset_parts`, `job_material_lines`), and the
fleet / work-order / equipment tables (candidates for later). The pure rule is
`isStaleWrite` in `lib/core/services/sync/stale_write.dart`.

A skipped edit is lost on purpose; the device keeps its local copy until the next
`refreshFromCloud` pulls the newer row (it keeps whichever copy is newer).

### Purchase order numbers

New orders get a provisional `NEW-xxxxxxxx` number offline (shown as "Number
pending"). A `BEFORE INSERT` trigger on `purchase_orders` replaces it with the
next `PO-0001` from `po_counters`, so two tablets never collide on
`unique (tenant_id, po_number)`. `refreshFromCloud` adopts the server number
into the local order (lines stay linked by order id). A number the user typed is
kept as is (anything not starting with `NEW-`). Edge case: a receive done while
the number is still pending writes the provisional `NEW-xxxx` into the stock
movement note and price entry; the order is found by id, so nothing breaks, only
that note keeps the provisional text. Receive after the order has synced to get
the real number in notes.

### Profile approvals

Approving a technician's profile change calls the `approve_profile_change` RPC,
which replaces the generator's `asset_parts` rows and marks the request approved
in one transaction. It needs a connection ("Connect to approve" offline; the
request stays pending). The new item list is still computed in Dart
(`ProfileChanges.applyChanges`). Rejecting still works offline through the normal
queue (`reject_profile_change` exists for symmetry but the app does not call it).

## Notes / follow-ups

- Sync is currently **push-only** (local → cloud). Pull/merge from the cloud can
  reuse the existing `fetchInspections()` remote datasource.
- The queue drains on connectivity changes and on each enqueue (see "Draining
  the queue" below). For long
  background windows, consider `workmanager` for periodic drains.

## Draining the queue

`SyncService.sync()` hands the loop to `SyncDrainer` (`sync_drainer.dart`). A
drain is a pass over the queue, oldest first, with a 40 ms gap between items.
A request that arrives *during* a drain (a bulk import keeps enqueuing while its
first rows upload) is remembered and triggers another pass, so the whole queue
empties in one run.

**Fixed 2026-11-07.** Before this, such requests were dropped, so a large import
uploaded only the rows queued before the drain started (about 100) and the rest
waited for an app relaunch. Regression tests: 250 items in one run, and 63 items
added mid-drain (`test/sync/sync_drainer_test.dart`).

Failure handling is unchanged: a failed item gets `attempts + 1` and
`lastError`, waits out exponential backoff, becomes `failed` after 8 attempts,
and never blocks the items after it. A run stamps **last synced** only when it
had no failures; the time is saved in preferences, so it survives a relaunch.

A null `assigned_to_user_id` is now sent to the cloud (it used to be stripped,
so unassigning a task never cleared the column).

## Sync centre and offline banner

Tapping the app-bar indicator opens a bottom sheet (`showSyncCentre`):

- last sync time, an Offline or Syncing chip, and **Sync now**;
- pending items grouped by friendly name (Parts, Stock movements, Generator
  parts, Inspections, Maintenance records...), from `summarizeQueue` in
  `sync_summary.dart` (add a name there for every new synced table);
- a **Failed** section with each item's error, **Retry** per item and **Retry
  all**.

An **offline banner** under the app bar reads "Changes are saved on this device
and will upload when you are back online". It shows only while offline with
items pending.

`PendingUploadBadge(table:, recordId:)` (`lib/shared/widgets/`) shows a small
cloud icon, "Not uploaded yet", for a record that is still queued. It is used on
maintenance list cards and on vehicle inspection rows (the Inspection Log and
the Inspections tab of a vehicle). One provider (`pendingRecordKeysProvider`)
reads the queue once per change, so any number of badges share it.

**Vehicle inspections sync.** `VehicleInspectionRepository` still keeps the
records in the local `vehicle_inspections` box, and now also queues an upsert
(save) or delete into the outbox for the `vehicle_inspections` table (shown as
"Vehicle inspections" in the sync centre). The row holds the whole inspection in
a `payload` json column plus a few typed columns. `refreshFromCloud` runs when
the log or a vehicle's inspections open (in the background, silent on failure):
it first queues any local inspection never queued (records from before syncing,
tracked by `s:<id>` markers in the small `vehicle_inspections_sync` box), then
merges cloud rows, the cloud copy winning only if its `updated_at` is newer than
the local last write. A locally deleted id is not brought back by a pull.
Photos and signature images already upload as files through the existing photo
and signature backup paths; the row only stores the signature file paths.


## Server-side cleanup and daily summary (Edge Functions)

Two scheduled functions live in `supabase/functions/` (setup, secrets and the
cron SQL are in `supabase/functions/README.md`). Both default to a dry run and
are protected by the `x-cron-secret` header or the service role key.

| Function | What it does |
| --- | --- |
| `retention-cleanup` | Nightly. Applies `tenant_retention_policies`: removes archived (completed) maintenance jobs, their rows and storage files (`photos/maintenance/`, `signatures/maintenance/`, `pdfs/maintenance/`) and generated report PDFs older than the policy. Deletes in batches of 100 and at most 2000 files per run. |
| `daily-digest` | Each morning. One summary email per company to active admins, supervisors and dispatchers: overdue tasks, Red sites, overdue inspections, parts to reorder, late purchase orders, open maintenance follow-ups. |

Not live until deployed with `--no-verify-jwt`, `CRON_SECRET` is set and the
schedule is created. Storage paths do not include the tenant, so report
deletion applies only on a single-company project (see the README).
