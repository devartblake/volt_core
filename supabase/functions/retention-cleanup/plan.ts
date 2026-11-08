// Pure selection logic for the retention-cleanup function. No Deno, network or
// Supabase imports: everything comes in as plain arrays so it is unit-tested
// with Node (see plan.test.ts).
//
// Time math is done on UTC epoch milliseconds, so daylight saving and the
// server time zone cannot move a cutoff.

export const DAY_MS = 24 * 60 * 60 * 1000;

export type Policy = {
  archived_maintenance_days?: number | null;
  generated_report_days?: number | null;
};

export type JobRow = {
  id: string;
  is_archived?: boolean | null;
  archived_at?: string | null;
  is_completed?: boolean | null;
  completed_at?: string | null;
  updated_at?: string | null;
};

export type StorageObject = { name: string; created_at: string | null };

export type AttachmentRow = {
  id: string;
  job_id: string;
  bucket_name?: string | null;
  file_path: string;
};

export type JobPlan = {
  id: string;
  /** When the job became "archived", as epoch ms (the age clock). */
  referenceMs: number;
  paths: string[];
  attachmentIds: string[];
};

export type TenantPlan = {
  archivedCutoff: string | null;
  reportCutoff: string | null;
  jobs: JobPlan[];
  reportPaths: string[];
  /** Objects selected (job files plus report files). */
  objectCount: number;
  /** True when the per-run budget stopped something from being selected. */
  capped: boolean;
  /** Jobs skipped because their files alone exceed the whole budget. */
  oversizeJobIds: string[];
};

/** 0, null, undefined, negative, NaN all mean "keep forever". */
export function retentionDays(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const n = Math.floor(value);
  return n > 0 ? n : null;
}

/** Epoch ms for an ISO string, or null when missing or unparseable. */
export function parseMs(value: string | null | undefined): number | null {
  if (typeof value !== "string" || value.trim() === "") return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

/** Anything strictly older than this instant qualifies. */
export function cutoffMs(nowMs: number, days: number): number {
  return nowMs - days * DAY_MS;
}

export type JobOptions = {
  /**
   * The app has no archive step of its own: its "Archive" list is simply the
   * completed jobs. When true (default) a completed job ages from
   * completed_at, in addition to jobs flagged is_archived.
   */
  includeCompleted?: boolean;
};

/** The instant a job's retention clock starts, or null when it is not archived. */
export function jobReferenceMs(
  job: JobRow,
  options: JobOptions = {},
): number | null {
  const includeCompleted = options.includeCompleted !== false;
  if (job.is_archived === true) {
    return parseMs(job.archived_at) ?? parseMs(job.updated_at);
  }
  if (includeCompleted && job.is_completed === true) {
    return parseMs(job.completed_at) ?? parseMs(job.updated_at);
  }
  return null;
}

/** Jobs whose reference instant is strictly before the cutoff, oldest first. */
export function selectExpiredJobs(
  jobs: JobRow[],
  cutoff: number,
  options: JobOptions = {},
): Array<{ job: JobRow; referenceMs: number }> {
  const out: Array<{ job: JobRow; referenceMs: number }> = [];
  for (const job of jobs) {
    const ref = jobReferenceMs(job, options);
    if (ref === null) continue;
    if (ref < cutoff) out.push({ job, referenceMs: ref });
  }
  out.sort((a, b) =>
    a.referenceMs - b.referenceMs || a.job.id.localeCompare(b.job.id)
  );
  return out;
}

/**
 * Storage paths the app writes for one maintenance job:
 *   photos/maintenance/<jobId>/<file>
 *   signatures/maintenance/<jobId>_<type>.png
 *   pdfs/maintenance/Maintenance_<site>_<date>_<first 8 chars of id>.pdf
 */
export function storagePathsForJob(
  jobId: string,
  objects: StorageObject[],
): string[] {
  if (!jobId) return [];
  const short = jobId.length > 8 ? jobId.substring(0, 8) : jobId;
  const photoPrefix = `photos/maintenance/${jobId}/`;
  const sigPrefix = `signatures/maintenance/${jobId}_`;
  const pdfPrefix = "pdfs/maintenance/";
  const pdfSuffix = `_${short}.pdf`;
  const out: string[] = [];
  for (const o of objects) {
    const n = o.name;
    if (n.startsWith(photoPrefix) && n.length > photoPrefix.length) {
      out.push(n);
    } else if (n.startsWith(sigPrefix)) {
      out.push(n);
    } else if (
      n.startsWith(pdfPrefix) &&
      n.indexOf("/", pdfPrefix.length) === -1 &&
      n.startsWith("Maintenance_", pdfPrefix.length) &&
      n.endsWith(pdfSuffix)
    ) {
      out.push(n);
    }
  }
  return out;
}

/** Generated-report PDFs under any prefix, created strictly before the cutoff. */
export function selectExpiredReports(
  objects: StorageObject[],
  prefixes: string[],
  cutoff: number,
): string[] {
  const out: string[] = [];
  for (const o of objects) {
    if (!prefixes.some((p) => p.length > 0 && o.name.startsWith(p))) continue;
    if (!o.name.toLowerCase().endsWith(".pdf")) continue;
    const created = parseMs(o.created_at);
    if (created === null) continue;
    if (created < cutoff) out.push(o.name);
  }
  out.sort();
  return out;
}

export function chunk<T>(items: T[], size: number): T[][] {
  const n = Math.max(1, Math.floor(size));
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += n) out.push(items.slice(i, i + n));
  return out;
}

export type PlanInput = {
  policy: Policy;
  jobs: JobRow[];
  /** Storage listing for the maintenance prefixes (photos, signatures, pdfs). */
  maintenanceObjects: StorageObject[];
  /** Storage listing covering the report prefixes. */
  reportObjects: StorageObject[];
  /** maintenance_attachments rows for this tenant. */
  attachments: AttachmentRow[];
  /** Prefixes that belong to this tenant's generated reports. */
  reportPrefixes: string[];
  bucket: string;
  nowMs: number;
  /** How many storage objects may still be selected in this run. */
  budget: number;
  includeCompleted?: boolean;
};

export function planTenant(input: PlanInput): TenantPlan {
  const archivedDays = retentionDays(input.policy.archived_maintenance_days);
  const reportDays = retentionDays(input.policy.generated_report_days);
  const totalBudget = Math.max(0, Math.floor(input.budget));
  let remaining = totalBudget;
  let capped = false;
  const claimed = new Set<string>();
  const jobs: JobPlan[] = [];
  const oversizeJobIds: string[] = [];

  let archivedCutoff: number | null = null;
  if (archivedDays !== null) {
    archivedCutoff = cutoffMs(input.nowMs, archivedDays);
    const expired = selectExpiredJobs(input.jobs, archivedCutoff, {
      includeCompleted: input.includeCompleted,
    });
    const byJob = new Map<string, AttachmentRow[]>();
    for (const a of input.attachments) {
      const list = byJob.get(a.job_id) ?? [];
      list.push(a);
      byJob.set(a.job_id, list);
    }
    for (const { job, referenceMs } of expired) {
      const atts = (byJob.get(job.id) ?? []).filter((a) =>
        (a.bucket_name ?? input.bucket) === input.bucket && a.file_path
      );
      const paths = Array.from(
        new Set([
          ...atts.map((a) => a.file_path),
          ...storagePathsForJob(job.id, input.maintenanceObjects),
        ]),
      ).filter((p) => !claimed.has(p));
      if (paths.length > remaining) {
        capped = true;
        if (paths.length > totalBudget) oversizeJobIds.push(job.id);
        continue;
      }
      for (const p of paths) claimed.add(p);
      remaining -= paths.length;
      jobs.push({
        id: job.id,
        referenceMs,
        paths,
        attachmentIds: atts.map((a) => a.id),
      });
    }
  }

  let reportCutoff: number | null = null;
  let reportPaths: string[] = [];
  if (reportDays !== null) {
    reportCutoff = cutoffMs(input.nowMs, reportDays);
    const all = selectExpiredReports(
      input.reportObjects,
      input.reportPrefixes,
      reportCutoff,
    ).filter((p) => !claimed.has(p));
    if (all.length > remaining) capped = true;
    reportPaths = all.slice(0, remaining);
    remaining -= reportPaths.length;
  }

  const objectCount = jobs.reduce((n, j) => n + j.paths.length, 0) +
    reportPaths.length;
  return {
    archivedCutoff: archivedCutoff === null
      ? null
      : new Date(archivedCutoff).toISOString(),
    reportCutoff: reportCutoff === null
      ? null
      : new Date(reportCutoff).toISOString(),
    jobs,
    reportPaths,
    objectCount,
    capped,
    oversizeJobIds,
  };
}
