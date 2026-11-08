// Supabase Edge Function: daily-digest
//
// Builds ONE summary email per tenant for its active admins, supervisors and
// dispatchers: overdue scheduled tasks, Red sites, overdue inspections, parts to
// reorder, late purchase orders and open maintenance follow-ups. Sections with
// nothing to say are left out; tenants with nothing at all are skipped.
//
// Callable ONLY with the service role key (Authorization: Bearer ...) or the
// shared secret header `x-cron-secret` equal to the CRON_SECRET function secret.
// Deploy with --no-verify-jwt (the cron caller has no user JWT); see README.
//
// Request JSON body (all optional):
//   { "dryRun": false,       // default TRUE: return composed digests, send nothing
//     "tenantId": "<uuid>" } // limit to one tenant
//
// Email goes out over the same SMTP secrets as send-report-email.
// Selection lives in digest_data.ts, wording in compose.ts (both pure, tested).

import { createClient } from "npm:@supabase/supabase-js@2";
import { isCronAuthorized, parseDryRun } from "../_shared/auth.ts";
import { createMailer } from "../_shared/smtp.ts";
import type { Mailer } from "../_shared/smtp.ts";
import { composeDigest } from "./compose.ts";
import type { Composed } from "./compose.ts";
import {
  digestRecipients,
  openFollowUps,
  overdueInspections,
  overduePurchaseOrders,
  overdueTasks,
  redSites,
  stockAlerts,
} from "./digest_data.ts";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// deno-lint-ignore no-explicit-any
type Db = any;
const PAGE = 1000;

/** Read every row of a query built by `build(from, to)` (PostgREST paging). */
async function readAll(
  // deno-lint-ignore no-explicit-any
  build: (from: number, to: number) => any,
  label: string,
  // deno-lint-ignore no-explicit-any
): Promise<any[]> {
  // deno-lint-ignore no-explicit-any
  let rows: any[] = [];
  for (let from = 0;; from += PAGE) {
    const { data, error } = await build(from, from + PAGE - 1);
    if (error) throw new Error(`${label}: ${error.message}`);
    rows = rows.concat(data ?? []);
    if (!data || data.length < PAGE) break;
  }
  return rows;
}

type TenantResult = {
  tenantId: string;
  name: string;
  status: "skipped" | "dry-run" | "sent" | "error";
  reason?: string;
  recipientCount: number;
  digest?: Composed;
  error?: string;
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorized = isCronAuthorized({
    cronSecretHeader: req.headers.get("x-cron-secret"),
    authorizationHeader: req.headers.get("authorization"),
    cronSecret: Deno.env.get("CRON_SECRET"),
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  });
  if (!authorized) return json({ error: "Unauthorized" }, 401);

  let body: Record<string, unknown> = {};
  try {
    const text = await req.text();
    if (text.trim() !== "") body = JSON.parse(text);
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }
  const dryRun = parseDryRun(body);
  const onlyTenant = typeof body.tenantId === "string" ? body.tenantId : null;

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "Supabase env not available" }, 500);
  const db: Db = createClient(url, key, { auth: { persistSession: false } });
  const nowMs = Date.now();

  let mailer: Mailer | null = null;
  if (!dryRun) {
    const m = createMailer();
    if ("error" in m) return json({ error: m.error }, 500);
    mailer = m.mailer;
  }

  let tenantQuery = db.from("tenants").select("id,name");
  if (onlyTenant) tenantQuery = tenantQuery.eq("id", onlyTenant);
  const { data: tenants, error: tenantErr } = await tenantQuery;
  if (tenantErr) {
    return json({ error: `Could not read tenants: ${tenantErr.message}` }, 500);
  }

  const results: TenantResult[] = [];

  for (const t of tenants ?? []) {
    const tenantId: string = t.id;
    const result: TenantResult = {
      tenantId,
      name: t.name ?? "",
      status: "skipped",
      recipientCount: 0,
    };
    results.push(result);

    try {
      // Recipients first: no one to email means no need to query the rest.
      const members = await readAll(
        (a, b) =>
          db.from("tenant_members")
            .select("user_id,role,is_active")
            .eq("tenant_id", tenantId)
            .in("role", ["admin", "supervisor", "dispatcher"])
            .eq("is_active", true)
            .order("user_id")
            .range(a, b),
        "tenant_members",
      );
      let recipients: string[] = [];
      if (members.length > 0) {
        // select("*") so a future opt-out column (daily_digest_opt_out) is
        // honored without a code change; today the table has no such column.
        const { data: profiles, error } = await db
          .from("user_profiles")
          .select("*")
          .in("user_id", members.map((m: { user_id: string }) => m.user_id));
        if (error) throw new Error(`user_profiles: ${error.message}`);
        recipients = digestRecipients(members, profiles ?? []);
      }
      result.recipientCount = recipients.length;
      if (recipients.length === 0) {
        result.reason = "no eligible recipients";
        continue;
      }

      const tasks = await readAll(
        (a, b) =>
          db.from("schedule_tasks")
            .select("id,title,site_code,status,scheduled_date,schedule_at")
            .eq("tenant_id", tenantId)
            .in("status", ["scheduled", "overdue"])
            .order("id")
            .range(a, b),
        "schedule_tasks",
      );

      // payload->>next_due_at is read only if the app ever stores it there.
      const inspections = await readAll(
        (a, b) =>
          db.from("inspections")
            .select(
              "id,site_code,site_grade,service_date,status,next_due_at:payload->>next_due_at",
            )
            .eq("tenant_id", tenantId)
            .order("id")
            .range(a, b),
        "inspections",
      );

      const parts = await readAll(
        (a, b) =>
          db.from("parts_catalog")
            .select("id,part_number,name,min_stock,is_active")
            .eq("tenant_id", tenantId)
            .eq("is_active", true)
            .order("id")
            .range(a, b),
        "parts_catalog",
      );
      const stock = await readAll(
        (a, b) =>
          db.from("inventory_stock")
            .select("part_id,on_hand")
            .eq("tenant_id", tenantId)
            .order("part_id")
            .range(a, b),
        "inventory_stock",
      );

      const orders = await readAll(
        (a, b) =>
          db.from("purchase_orders")
            .select("id,po_number,status,expected_on")
            .eq("tenant_id", tenantId)
            .in("status", ["sent", "partial"])
            .order("id")
            .range(a, b),
        "purchase_orders",
      );

      const jobs = await readAll(
        (a, b) =>
          db.from("maintenance_jobs")
            .select(
              "id,title,site_code,requires_follow_up,is_completed,is_archived",
            )
            .eq("tenant_id", tenantId)
            .eq("requires_follow_up", true)
            .eq("is_completed", false)
            .order("id")
            .range(a, b),
        "maintenance_jobs",
      );

      const digest = composeDigest({
        tenantName: result.name,
        nowMs,
        data: {
          overdueTasks: overdueTasks(tasks, nowMs),
          redSites: redSites(inspections),
          overdueInspections: overdueInspections(inspections, nowMs),
          stockAlerts: stockAlerts(parts, stock),
          overduePurchaseOrders: overduePurchaseOrders(orders, nowMs),
          followUps: openFollowUps(jobs),
        },
      });
      if (digest === null) {
        result.reason = "nothing to report";
        continue;
      }

      if (dryRun || mailer === null) {
        result.status = "dry-run";
        result.digest = digest;
        continue;
      }

      // One message per tenant. Recipients are blind-copied so team members do
      // not see each other's addresses; "to" is the sending mailbox itself.
      await mailer.send({
        to: mailer.from,
        bcc: recipients,
        subject: digest.subject,
        text: digest.text,
        html: digest.html,
      });
      result.status = "sent";
    } catch (err) {
      result.status = "error";
      result.error = String(err);
    }
  }

  if (mailer) await mailer.close();

  const response = { dryRun, tenants: results };
  console.log(JSON.stringify({
    fn: "daily-digest",
    dryRun,
    tenants: results.map((r) => ({
      tenantId: r.tenantId,
      status: r.status,
      reason: r.reason,
      recipientCount: r.recipientCount,
      error: r.error,
    })),
  }));
  return json(response);
});
