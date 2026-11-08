// Shared SMTP sender for Edge Functions that email on their own (daily-digest).
// Uses the same function secrets as send-report-email:
//   SMTP_HOST, SMTP_PORT (default 587), SMTP_USER, SMTP_PASS, SMTP_FROM
//
// send-report-email still carries its own copy of this code on purpose: it is
// deployed and working, and is left unchanged. If it is ever switched to this
// helper, behaviour must stay identical (port 465 = implicit TLS, otherwise
// STARTTLS handled by the library).

import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

export type MailMessage = {
  to: string | string[];
  bcc?: string[];
  subject: string;
  text: string;
  html?: string;
};

export type Mailer = {
  from: string;
  send(message: MailMessage): Promise<void>;
  close(): Promise<void>;
};

/** Returns a mailer, or an error string when the SMTP secrets are missing. */
export function createMailer(): { mailer: Mailer } | { error: string } {
  const host = Deno.env.get("SMTP_HOST");
  const port = Number(Deno.env.get("SMTP_PORT") ?? "587");
  const user = Deno.env.get("SMTP_USER");
  const pass = Deno.env.get("SMTP_PASS");
  const from = Deno.env.get("SMTP_FROM") ?? user;
  if (!host || !user || !pass || !from) {
    return { error: "SMTP not configured (SMTP_HOST/SMTP_USER/SMTP_PASS)" };
  }

  const client = new SMTPClient({
    connection: {
      hostname: host,
      port,
      tls: port === 465,
      auth: { username: user, password: pass },
    },
  });

  return {
    mailer: {
      from,
      async send(m: MailMessage): Promise<void> {
        await client.send({
          from,
          to: m.to,
          bcc: m.bcc,
          subject: m.subject,
          content: m.text,
          html: m.html,
        });
      },
      async close(): Promise<void> {
        try {
          await client.close();
        } catch (_) {
          // ignore close errors
        }
      },
    },
  };
}
