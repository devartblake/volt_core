// Supabase Edge Function: retention-cleanup
//
// Nightly enforcement of tenant_retention_policies:
//   1. archived maintenance older than archived_maintenance_days: its storage
//      files, then maintenance_records / maintenance_attachments rows, then the
//      maintenance_jobs row.
//   2. generated report PDFs older than generated_report_days (storage only;
//      inspections are never touched).
// 0 or null days = keep forever.
//
// Callable ONLY with the service role key (Authorization: Bearer ...) or the
// shared secret header `x-cron-secret` equal to the CRON_SECRET function secret.
// Deploy with --no-verify-jwt (the cron caller has no user JWT); see README.
//
// Request JSON body (all optional):
//   { "dryRun": false,        // default TRUE: only report counts
//     "tenantId": "<uuid>",   // limit to one tenant
//     "maxObjects": 2000,     // storage objects per run, hard max 5000
//     "includeCompleted": true }  // false = only is_archived jobs
//
// All selection logic lives in plan.ts (pure, unit-tested).

import { createClient } from "npm:@supabase/supabase-js@2";
import { isCronAuthorized, parseDryRun } from "../_shared/auth.ts";
import {
  chunk,
  planTenant,
  selectExpiredJobs,
  retentionDays,
} from "./plan.ts";
import type {
  AttachmentRow,
  JobRow,
  Policy,
  StorageObject,
} from "./plan.ts";
import { walkStorage } from "./storage_walk.ts";

const BATCH = 100;
const DEFAULT_MAX_OBJECTS = 2000;
const HARD_MAX_OBJECTS = 5000;
const LIST_CAP = 20000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

type TenantSummary = {
  tenantId: string;
  archivedCutoff: string | null;
  reportCutoff: string | null;
  jobsSelected: number;
  jobsDeleted: number;
  maintenanceFilesSelected: number;
  maintenanceFilesDeleted: number;
  reportFilesSelected: number;
  reportFilesDeleted: number;
  capped: boolean;
  oversizeJobIds: string[];
  sample: string[];
  errors: string[];
};

// deno-lint-ignore no-explicit-any
type Db = any;

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
  const includeCompleted = body.includeCompleted !== false;
  const requestedMax = typeof body.maxObjects === "number"
    ? Math.floor(body.maxObjects)
    : DEFAULT_MAX_OBJECTS;
  const maxObjects = Math.min(
    HARD_MAX_OBJECTS,
    Math.max(0, Number.isFinite(requestedMax) ? requestedMax : DEFAULT_MAX_OBJECTS),
  );

  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return json({ error: "Supabase env not available" }, 500);
  const db: Db = createClient(url, key, { auth: { persistSession: false } });
  const bucket = Deno.env.get("SUPABASE_STORAGE_BUCKET") || "voltcore-files";
  const nowMs = Date.now();

  // ---- policies -----------------------------------------------------------
  let policyQuery = db
    .from("tenant_retention_policies")
    .select("tenant_id,archived_maintenance_days,generated_report_days");
  if (onlyTenant) policyQuery = policyQuery.eq("tenant_id", onlyTenant);
  const { data: policies, error: policyErr } = await policyQuery;
  if (policyErr) {
    return json({ error: `Could not read policies: ${policyErr.message}` }, 500);
  }

  const { count: tenantCount } = await db
    .from("tenants")
    .select("id", { count: "exact", head: true });
  const singleTenant = tenantCount === 1;

  const active = (policies ?? []).filter((p: Policy) =>
    retentionDays(p.archived_maintenance_days) !== null ||
    retentionDays(p.generated_report_days) !== null
  );

  // ---- storage listings (once per run) -----------------------------------
  const listWarnings: string[] = [];
  const list = async (
    prefix: string,
    offset: number,
    limit: number,
  ) => {
    const { data, error } = await db.storage.from(bucket).list(prefix, {
      limit,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) throw new Error(error.message);
    return data ?? [];
  };

  let maintenanceObjects: StorageObject[] = [];
  let reportObjects: StorageObject[] = [];
  const needArchived = active.some((p: Policy) =>
    retentionDays(p.archived_maintenance_days) !== null
  );
  const needReports = active.some((p: Policy) =>
    retentionDays(p.generated_report_days) !== null
  );
  try {
    if (needArchived) {
      for (
        const prefix of [
          "photos/maintenance",
          "signatures/maintenance",
          "pdfs/maintenance",
        ]
      ) {
        const r = await walkStorage(list, prefix, { maxObjects: LIST_CAP });
        maintenanceObjects = maintenanceObjects.concat(r.objects);
        if (r.truncated) listWarnings.push(`listing of ${prefix} truncated`);
      }
    }
    if (needReports) {
      const r = await walkStorage(list, "pdfs", { maxObjects: LIST_CAP });
      reportObjects = r.objects;
      if (r.truncated) listWarnings.push("listing of pdfs truncated");
    }
  } catch (err) {
    return json({ error: `Storage listing failed: ${String(err)}` }, 502);
  }

  // ---- per tenant ---------------------------------------------------------
  let budget = maxObjects;
  const results: TenantSummary[] = [];

  for (const policy of active) {
    const tenantId: string = policy.tenant_id;
    const summary: TenantSummary = {
      tenantId,
      archivedCutoff: null,
      reportCutoff: null,
      jobsSelected: 0,
      jobsDeleted: 0,
      maintenanceFilesSelected: 0,
      maintenanceFilesDeleted: 0,
      reportFilesSelected: 0,
      reportFilesDeleted: 0,
      capped: false,
      oversizeJobIds: [],
      sample: [],
      errors: [],
    };
    results.push(summary);

    try {
      // Jobs that could be archived/completed (the age test is in plan.ts).
      let jobs: JobRow[] = [];
      if (retentionDays(policy.archived_maintenance_days) !== null) {
        for (let from = 0;; from += 1000) {
          const { data, error } = await db
            .from("maintenance_jobs")
            .select(
              "id,is_archived,archived_at,is_completed,completed_at,updated_at",
            )
            .eq("tenant_id", tenantId)
            .or("is_archived.eq.true,is_completed.eq.true")
            .order("id", { ascending: true })
            .range(from, from + 999);
          if (error) throw new Error(`read jobs: ${error.message}`);
          jobs = jobs.concat(data ?? []);
          if (!data || data.length < 1000) break;
        }
      }

      // Attachment rows only for jobs that are about to expire.
      let attachments: AttachmentRow[] = [];
      const days = retentionDays(policy.archived_maintenance_days);
      if (days !== null && jobs.length > 0) {
        const expiredIds = selectExpiredJobs(
          jobs,
          nowMs - days * 24 * 60 * 60 * 1000,
          { includeCompleted },
        ).map((x) => x.job.id);
        for (const ids of chunk(expiredIds, BATCH)) {
          const { data, error } = await db
            .from("maintenance_attachments")
            .select("id,job_id,bucket_name,file_path")
            .eq("tenant_id", tenantId)
            .in("job_id", ids);
          if (error) throw new Error(`read attachments: ${error.message}`);
          attachments = attachments.concat(data ?? []);
        }
      }

      const reportPrefixes = [`pdfs/${tenantId}/`];
      // Today every tenant's PDFs share pdfs/<kind>/..., with no tenant in the
      // path. Only a single-tenant project can safely treat all of pdfs/ as
      // this tenant's reports.
      if (singleTenant) reportPrefixes.push("pdfs/");

      const plan = planTenant({
        policy,
        jobs,
        maintenanceObjects,
        reportObjects,
        attachments,
        reportPrefixes,
        bucket,
        nowMs,
        budget,
        includeCompleted,
      });
      budget -= plan.objectCount;
      summary.archivedCutoff = plan.archivedCutoff;
      summary.reportCutoff = plan.reportCutoff;
      summary.jobsSelected = plan.jobs.length;
      summary.maintenanceFilesSelected = plan.jobs.reduce(
        (n, j) => n + j.paths.length,
        0,
      );
      summary.reportFilesSelected = plan.reportPaths.length;
      summary.capped = plan.capped;
      summary.oversizeJobIds = plan.oversizeJobIds;
      summary.sample = [
        ...plan.jobs.flatMap((j) => j.paths),
        ...plan.reportPaths,
      ].slice(0, 20);

      if (dryRun) continue;

      // 1. Job files, then job rows (a job whose files failed is left alone so
      //    tomorrow's run retries it).
      const goodJobIds: string[] = [];
      for (const job of plan.jobs) {
        let ok = true;
        for (const batch of chunk(job.paths, BATCH)) {
          const { data, error } = await db.storage.from(bucket).remove(batch);
          if (error) {
            ok = false;
            summary.errors.push(`remove files of job ${job.id}: ${error.message}`);
            break;
          }
          summary.maintenanceFilesDeleted += (data ?? []).length;
        }
        if (ok) goodJobIds.push(job.id);
      }
      for (const ids of chunk(goodJobIds, BATCH)) {
        const steps = [
          ["maintenance_attachments", "job_id"],
          ["maintenance_records", "job_id"],
          ["maintenance_jobs", "id"],
        ] as const;
        let batchOk = true;
        for (const [table, col] of steps) {
          const { error } = await db
            .from(table)
            .delete()
            .eq("tenant_id", tenantId)
            .in(col, ids);
          if (error) {
            batchOk = false;
            summary.errors.push(`delete ${table}: ${error.message}`);
            break;
          }
        }
        if (batchOk) {
          summary.jobsDeleted += ids.length;
        } else {
          // One blocked row (for example a foreign key) must not hold back the
          // other 99: retry the batch one job at a time.
          for (const id of ids) {
            let single = true;
            for (const [table, col] of steps) {
              const { error } = await db
                .from(table)
                .delete()
                .eq("tenant_id", tenantId)
                .eq(col, id);
              if (error) {
                single = false;
                summary.errors.push(`delete ${table} ${id}: ${error.message}`);
                break;
              }
            }
            if (single) summary.jobsDeleted += 1;
          }
        }
      }

      // 2. Generated report PDFs.
      for (const batch of chunk(plan.reportPaths, BATCH)) {
        const { data, error } = await db.storage.from(bucket).remove(batch);
        if (error) {
          summary.errors.push(`remove reports: ${error.message}`);
          break;
        }
        summary.reportFilesDeleted += (data ?? []).length;
      }
    } catch (err) {
      summary.errors.push(String(err));
    }
  }

  const response = {
    dryRun,
    bucket,
    maxObjects,
    objectsSelected: maxObjects - budget,
    capReached: budget <= 0 || results.some((r) => r.capped),
    singleTenantProject: singleTenant,
    warnings: listWarnings,
    tenants: results,
  };
  console.log(JSON.stringify({ fn: "retention-cleanup", ...response }));
  return json(response);
});
