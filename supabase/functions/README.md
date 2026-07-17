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
