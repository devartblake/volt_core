# Photos, reminders, path reliability, and CI

## Photo attachments

Inspection and maintenance forms include a **Photos** section
(`PhotoAttachmentsSection`) for capturing photos from the camera or gallery
(`image_picker`).

- Image bytes are stored under the managed tree at
  `photos/<ownerType>/<ownerId>/<uuid>.<ext>`.
- Metadata (`PhotoAttachment`) is persisted as JSON in an adapter-free
  `Box<String>` (`PhotoRepository`) — no Hive code generation.
- Each photo is queued for **Supabase Storage backup** through the existing
  sync engine (`photos/...`).
- Photos render as an **appendix page** in the generated inspection and
  maintenance PDFs (with captions).
- `PhotoService` is the facade (add / list / caption / delete).

Platform config: iOS `NSCameraUsageDescription` added; photo box opened at
startup.

## Schedule reminders (local notifications)

`NotificationService` (`flutter_local_notifications` + `timezone`) schedules a
local reminder at each scheduled task's appointment time.

- Inexact scheduling (`AndroidScheduleMode.inexactAllowWhileIdle`) — no
  exact-alarm permission needed.
- Permission is requested **in context** on first scheduling, not at cold
  start.
- Wired into the schedule dialog (create) and `ScheduleRepositoryImpl`
  (save/delete): active tasks schedule, completed/cancelled/deleted cancel.
- Absolute-instant scheduling via a UTC `TZDateTime`, so no device IANA
  timezone dependency is required.
- Android manifest: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, and the
  boot-reschedule receivers.

## Path reliability across iOS updates

iOS changes the app container path on every update/reinstall, which breaks
absolute paths stored in Hive (PDFs, signatures, photos). `PathResolver`
self-heals at read time: if the stored file is missing, it rebuilds the path
under the **current** app-data root by re-anchoring on a known managed subtree
(`pdfs/`, `signatures/`, `photos/`, `exports/`). Applied at every stored-path
read site (PDF open/print, export copy, email attachment, signature embedding,
photo display).

## Tests & CI

`test/` covers the pure-Dart logic that's cheapest to protect:

- `SyncOperation` JSON round-trip + dedup key
- `PhotoAttachment` JSON round-trip + copyWith
- `PathResolver.relativeUnderMarker` re-anchoring
- `maintenanceRecordToSupabaseJson` field mapping

CI (`.github/workflows/ci.yml`) runs on pushes to `main` / `claude/**` and on
PRs: `flutter pub get`, `flutter analyze` (fails on errors; tolerates existing
warnings/deprecations), and `flutter test`.
