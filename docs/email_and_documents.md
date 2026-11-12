# Server-side email & the document library

## Server-side email (`EmailService`)

Report emails are sent by a **Supabase Edge Function** (`send-report-email`),
not by the app. This removes SMTP host/credentials from the client bundle —
previously the app used `mailer` with SMTP settings read from the bundled
`.env`, which shipped those secrets to every device.

Flow:

```
EmailService.sendReportEmail(...)
    │  reads local PDF → base64
    ▼
supabase.functions.invoke('send-report-email', body: {to, subject, text, pdfBase64, filename})
    ▼
Edge Function (Deno)  ──►  SMTP send with attachment  (secrets live here)
```

- On **web** (no local file access) it falls back to a `mailto:` draft without
  an attachment.
- Failures raise `EmailException` with an actionable message.

### Deploying the function

Source: `supabase/functions/send-report-email/index.ts`.

```bash
supabase functions deploy send-report-email

# Set SMTP secrets once (never committed, never in the app bundle):
supabase secrets set \
  SMTP_HOST=smtp.yourhost.com \
  SMTP_PORT=587 \
  SMTP_USER=no-reply@yourdomain.com \
  SMTP_PASS=•••• \
  SMTP_FROM="A&S Electric <no-reply@yourdomain.com>"
```

The client only needs `SMTP_TO` (default recipient) in its env — that's not a
secret. All `SMTP_HOST/USER/PASS` keys were removed from the bundled env files.

## Document library

`DocumentLibraryPage` (route `/documents`, a tab in the Work section and also
linked from Settings → Data & Sync → Documents) is the one hub for every
generated PDF in the managed `pdfs/` tree:

- **Search** by filename; **type chips** with counts (All, Inspections,
  Maintenance, Vehicles, Other); **sort** newest, name or size; **date headers**
  (Today, This week, This month, Older) when sorted newest.
- **Summary line** ("12 documents, 8.4 MB") and **Clear old files**, which lists
  how many files are older than 90 days and asks before deleting (no undo).
- **Open** — in-app viewer (`PdfViewerPage`, rendered with the `printing`
  package) with print + share.
- **Print**, **Share** (native share sheet, `share_plus`) and **Email** — prompts
  for a recipient (default `SMTP_TO`) and sends via the server-side
  `EmailService`.
- **Delete** — asks first, hides the row and shows an **Undo** snackbar; the file
  is removed when the 5-second window ends (or when you leave the page). Removes
  the local copy only (any existing cloud backup is kept).
- **Multi-select** — long-press a row; share or delete several at once.

Logic (filtering, sorting, date grouping, the 90-day rule) is in
`domain/document_hub.dart`; open/print/share helpers are in
`presenter/document_actions.dart` and are reused by the vehicle Documents tab.

Enumeration lives in `PdfLibraryService.listDocuments()`, which walks the
`pdfs/` directory the storage layer already manages — no separate index.

### Dependencies

- `printing: ^5.13.4` — in-app PDF rendering (companion to the `pdf` package
  already used to generate reports).
- `mailer` was removed (client SMTP is gone).
