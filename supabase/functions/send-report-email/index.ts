// Supabase Edge Function: send-report-email
//
// Sends a report email with an optional PDF attachment over SMTP. SMTP
// credentials live here as Edge Function secrets and are NEVER shipped in the
// Flutter app bundle.
//
// Deploy:
//   supabase functions deploy send-report-email
//
// Configure secrets (once):
//   supabase secrets set SMTP_HOST=smtp.yourhost.com SMTP_PORT=587 \
//     SMTP_USER=no-reply@yourdomain.com SMTP_PASS=•••• \
//     SMTP_FROM="A&S Electric <no-reply@yourdomain.com>"
//
// Request JSON body:
//   { "to": string, "subject": string, "text": string,
//     "pdfBase64"?: string, "filename"?: string }

import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let payload: {
    to?: string;
    subject?: string;
    text?: string;
    pdfBase64?: string;
    filename?: string;
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { to, subject, text, pdfBase64, filename } = payload;
  if (!to || !subject) {
    return json({ error: "Missing required fields: to, subject" }, 400);
  }

  const host = Deno.env.get("SMTP_HOST");
  const port = Number(Deno.env.get("SMTP_PORT") ?? "587");
  const user = Deno.env.get("SMTP_USER");
  const pass = Deno.env.get("SMTP_PASS");
  const from = Deno.env.get("SMTP_FROM") ?? user;

  if (!host || !user || !pass) {
    return json(
      { error: "SMTP not configured (SMTP_HOST/SMTP_USER/SMTP_PASS)" },
      500,
    );
  }

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port,
      tls: port === 465,
      auth: { username: user, password: pass },
    },
  });

  try {
    const attachments = [];
    if (pdfBase64) {
      attachments.push({
        filename: filename ?? "report.pdf",
        contentType: "application/pdf",
        encoding: "base64",
        content: pdfBase64,
      });
    }

    await client.send({
      from: from!,
      to,
      subject,
      content: text ?? "",
      attachments: attachments.length ? attachments : undefined,
    });
    await client.close();

    return json({ ok: true });
  } catch (err) {
    try {
      await client.close();
    } catch (_) {
      // ignore close errors
    }
    return json({ error: `SMTP send failed: ${err}` }, 502);
  }
});
