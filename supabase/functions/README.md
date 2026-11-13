# Supabase Edge Functions

Server-side functions for Voltcore. Deployed with the Supabase CLI.

## send-report-email

Sends a report email with an optional PDF attachment over SMTP. SMTP
credentials live as function secrets and are never shipped in the Flutter app
bundle.

```bash
# Deploy
supabase functions deploy send-report-email

# Configure SMTP secrets (once)
supabase secrets set \
  SMTP_HOST=smtp.yourhost.com \
  SMTP_PORT=587 \
  SMTP_USER=no-reply@yourdomain.com \
  SMTP_PASS=•••• \
  SMTP_FROM="A&S Electric <no-reply@yourdomain.com>"
```

Request body (JSON):

```json
{
  "to": "office@example.com",
  "subject": "Report",
  "text": "See attached.",
  "pdfBase64": "<base64 PDF bytes, optional>",
  "filename": "report.pdf"
}
```

The Flutter client calls this via `EmailService`
(`lib/core/services/email/email_service.dart`).

## invite-user

Lets a tenant **admin** invite a new user by email. Creating a sign-in account
needs the service role key, so this runs server-side only; the key is injected
by Supabase and never ships in the app.

```bash
# Deploy. JWT verification stays ON (the default). Do not use --no-verify-jwt.
supabase functions deploy invite-user
```

Request body (JSON), sent with the signed-in caller's JWT:

```json
{
  "email": "new.person@example.com",
  "displayName": "New Person",
  "role": "technician",
  "phone": "+1 555 123 4567",
  "redirectTo": "https://your-app-url/after-invite",
  "tenantId": "<only needed if the caller administers several companies>",
  "divisionIds": ["<optional ids from public.divisions, at most 10>"],
  "divisionId": "<older single form, still accepted>"
}
```

`role` is one of `apprentice`, `technician`, `supervisor`, `dispatcher`,
`admin`. (`apprentice` needs the `20261113100000_apprentice_role.sql` migration
first.) `phone`, `redirectTo`, `tenantId`, `divisionIds` and `divisionId` are
optional.

`divisionIds` is an array of up to 10 uuids (duplicates are ignored); the older
single `divisionId` is merged into it. The function looks them up with the
service client and refuses the request (400, "That division is not available.")
unless every division exists, is active and belongs to the resolved company.
An invite only ADDS: missing `public.member_divisions` rows are inserted and
divisions the member already has are never removed. The first id is also
written to the deprecated `tenant_members.division_id` for older app builds.
Needs the `20261113110000_divisions.sql` and `20261114110000_member_divisions.sql`
migrations. **The repository copy is authoritative; the deployed copy must be
redeployed to pick up `divisionIds`** (until then the new app still sends the
first division as `divisionId`, so one division is kept).

Response: `{ "ok": true, "userId": "...", "invited": true, "role": "technician" }`.
`invited` is `false` when the person already had an account and was only added
to the company. Errors are `{ "error": "plain sentence" }` with status 400
(invalid input), 401 (not signed in), 403 (caller is not an active admin),
429 (more than 20 invitations by this caller in the last hour), 5xx (server).

Who can call it: an authenticated user who is an active `admin` in
`tenant_members`. The company is taken from the caller's own membership, never
from the request. Each invitation upserts `user_profiles` and `tenant_members`
and appends a `tenant_role_assignments` row with reason `Invited`
(re-inviting someone updates them, it does not duplicate).

Settings the owner must check in the Supabase dashboard:

- Authentication > URL Configuration: add the `redirectTo` address to the
  allowed Redirect URLs, otherwise the invite link falls back to the Site URL.
- Authentication > SMTP: configure a custom SMTP sender; the built-in sender is
  heavily rate limited and only emails project team members.
- Invited people must open the emailed link and set a password before they can
  sign in. Authentication > Attack Protection > leaked password protection is
  the owner's decision.

The Flutter client calls this through `InviteService`
(`lib/modules/admin/infra/services/invite_service.dart`); the pure rules are in
`validate.ts` and `plan.ts` and are tested with
`node --experimental-strip-types --test supabase/functions/invite-user/*.test.ts`.

## Scheduled functions (retention-cleanup and daily-digest)

These two run by themselves from a Supabase schedule, not from the app. They
share one guard: the caller must send **either** the service role key as
`Authorization: Bearer <key>` **or** the header `x-cron-secret: <CRON_SECRET>`.
Anything else gets `401`. Both comparisons are constant time
(`_shared/auth.ts`).

### Why `--no-verify-jwt`

By default Supabase rejects any call without a valid user JWT before the
function runs. A scheduled job has no signed-in user, so these two are
deployed with `--no-verify-jwt` and check the caller themselves (the secret
header or the service role key). **Never deploy them without that check
in place, and never put the cron secret in the app.**

```bash
supabase secrets set CRON_SECRET=<long random string>   # once
supabase functions deploy retention-cleanup --no-verify-jwt
supabase functions deploy daily-digest --no-verify-jwt
```

Secrets they need:

| Secret | Used by | Notes |
|---|---|---|
| `CRON_SECRET` | both | Shared secret for the `x-cron-secret` header. If unset, only the service role key works. |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `SMTP_FROM` | daily-digest | The same secrets `send-report-email` uses. |
| `SUPABASE_STORAGE_BUCKET` | retention-cleanup | Optional; defaults to `voltcore-files` like the app. |
| `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | both | Injected by Supabase automatically. |

### retention-cleanup

Enforces `tenant_retention_policies` for every tenant that has a policy (`0` or
empty days = keep forever):

1. **Archived maintenance** older than `archived_maintenance_days`: deletes the
   job's storage files (`photos/maintenance/<jobId>/`,
   `signatures/maintenance/<jobId>_*.png`, its `pdfs/maintenance/..._<first 8
   chars of id>.pdf`, plus any `maintenance_attachments.file_path`), then its
   `maintenance_attachments` and `maintenance_records` rows, then the
   `maintenance_jobs` row. If a job's files cannot be deleted the job is left
   for the next run.
   *What "archived" means:* the app has no archive step; its Archive list is
   simply the completed jobs. So a job counts when `is_archived = true`
   (age from `archived_at`, else `updated_at`) **or** `is_completed = true`
   (age from `completed_at`, else `updated_at`). Send
   `"includeCompleted": false` to only touch rows flagged `is_archived`.
2. **Generated reports**: deletes `.pdf` objects whose storage `created_at` is
   older than `generated_report_days`. Inspections themselves are never
   touched. Storage paths carry **no tenant** today (`pdfs/inspections/...`,
   `pdfs/maintenance/...`), so `pdfs/` is treated as a tenant's reports only
   when the project has exactly one tenant; `pdfs/<tenantId>/` is always
   honored. With several tenants and the current paths, reports are not
   deleted until the app writes tenant-prefixed paths.

Request (JSON, all optional): `{"dryRun": false, "tenantId": "<uuid>",
"maxObjects": 2000, "includeCompleted": true}`. **`dryRun` defaults to true**;
only `"dryRun": false` deletes. Deletes run in batches of 100, at most
`maxObjects` storage objects per run (default 2000, hard max 5000; the rest is
picked up the next night), and one tenant failing does not stop the others.

Response:

```json
{
  "dryRun": true, "bucket": "voltcore-files", "maxObjects": 2000,
  "objectsSelected": 12, "capReached": false, "singleTenantProject": true,
  "warnings": [],
  "tenants": [{
    "tenantId": "...", "archivedCutoff": "2025-11-08T03:00:00.000Z",
    "reportCutoff": null, "jobsSelected": 2, "jobsDeleted": 0,
    "maintenanceFilesSelected": 12, "maintenanceFilesDeleted": 0,
    "reportFilesSelected": 0, "reportFilesDeleted": 0,
    "capped": false, "oversizeJobIds": [], "sample": ["photos/maintenance/..."],
    "errors": []
  }]
}
```

### daily-digest

One email per tenant to its **active** admins, supervisors and dispatchers
(`tenant_members` role + `is_active`, address from `user_profiles.email`,
profile `is_active` not false). Recipients are blind-copied; the message is
addressed to the sending mailbox. Sections appear only when non-empty, each
shows a count and the first 10 items:

- overdue scheduled tasks (`schedule_tasks` scheduled/overdue, date in the past)
- sites whose latest inspection is graded Red
- inspections overdue by next-due date (see note below)
- parts out of stock or below `parts_catalog.min_stock` (`inventory_stock`)
- purchase orders `sent`/`partial` with `expected_on` in the past
- maintenance jobs with follow-up flagged and not completed

Subject: `Volt Core daily summary - YYYY-MM-DD` (UTC date). Tenants with nothing
to report, or with no eligible recipient, are skipped.

Request (JSON, optional): `{"dryRun": false, "tenantId": "<uuid>"}`.
**`dryRun` defaults to true**: the response contains the composed
`{subject, text, html}` per tenant and nothing is sent.

Response: `{"dryRun": true, "tenants": [{"tenantId", "name", "status":
"skipped" | "dry-run" | "sent" | "error", "reason"?, "recipientCount",
"digest"?, "error"?}]}`.

Notes:
- The inspections table has no `next_due_at` column and the app does not sync
  `nextDueAt`, so "overdue" is the latest inspection per site plus 365 days
  (the same default as the readiness screen) unless `payload.next_due_at`
  exists, which is read automatically if the app ever stores it.
- Per-user opt-out: `user_profiles.daily_digest_opt_out boolean not null
  default false` (migration `20261115100000_digest_opt_out.sql`). People set it
  in the app under Settings, Notifications, "Email me the daily summary" (shown
  to admins, supervisors and dispatchers). The function skips profiles where it
  is `true`; until the migration is run nobody is opted out.

### Scheduling (nightly)

Needs the `pg_cron` and `pg_net` extensions (Dashboard > Database >
Extensions). Store the secret once in Vault so it is not in the job text, then
schedule (times are UTC; 03:00 for cleanup, 12:00 for the digest = early
morning in New York):

```sql
select vault.create_secret('<same value as CRON_SECRET>', 'cron_secret');

select cron.schedule(
  'retention-cleanup-nightly', '0 3 * * *',
  $$
  select net.http_post(
    url := 'https://uwivfcxywrzcnyouuydj.supabase.co/functions/v1/retention-cleanup',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{"dryRun": false}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);

select cron.schedule(
  'daily-digest-morning', '0 12 * * *',
  $$
  select net.http_post(
    url := 'https://uwivfcxywrzcnyouuydj.supabase.co/functions/v1/daily-digest',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{"dryRun": false}'::jsonb,
    timeout_milliseconds := 120000
  );
  $$
);
```

Remove a job with `select cron.unschedule('retention-cleanup-nightly');`.
Alternative: Dashboard > Integrations > Cron > Create job, type "Supabase Edge
Function", pick the function, add the header `x-cron-secret`, and set the body.
**Schedule with `"dryRun": true` first**, read the result under Edge Functions >
Logs, and only then switch the body to `false`.

### Testing with dryRun

```bash
curl -s -X POST \
  "https://uwivfcxywrzcnyouuydj.supabase.co/functions/v1/retention-cleanup" \
  -H "x-cron-secret: $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{}'
curl -s -X POST \
  "https://uwivfcxywrzcnyouuydj.supabase.co/functions/v1/daily-digest" \
  -H "x-cron-secret: $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"tenantId": "<uuid>"}'
```

A call without the header (or with a wrong one) must return `401`.

### Unit tests (no Deno needed)

All decisions live in plain TypeScript modules (`retention-cleanup/plan.ts`,
`retention-cleanup/storage_walk.ts`, `daily-digest/digest_data.ts`,
`daily-digest/compose.ts`, `_shared/auth.ts`); `index.ts` only does I/O.

```bash
cd supabase/functions
node --experimental-strip-types --test _shared/auth.test.ts \
  retention-cleanup/plan.test.ts daily-digest/digest.test.ts
```
