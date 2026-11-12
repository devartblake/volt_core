import { test } from "node:test";
import assert from "node:assert/strict";
import {
  chunk,
  cutoffMs,
  DAY_MS,
  jobReferenceMs,
  planTenant,
  retentionDays,
  selectExpiredJobs,
  selectExpiredReports,
  storagePathsForJob,
} from "./plan.ts";
import type { PlanInput } from "./plan.ts";
import { walkStorage } from "./storage_walk.ts";
import type { ListEntry } from "./storage_walk.ts";

const NOW = Date.parse("2026-11-08T03:00:00Z");
const iso = (ms: number) => new Date(ms).toISOString();
const ID = "0a1b2c3d-1111-2222-3333-444455556666";

function input(over: Partial<PlanInput> = {}): PlanInput {
  return {
    policy: { archived_maintenance_days: 365, generated_report_days: 365 },
    jobs: [],
    maintenanceObjects: [],
    reportObjects: [],
    attachments: [],
    reportPrefixes: ["pdfs/"],
    bucket: "voltcore-files",
    nowMs: NOW,
    budget: 2000,
    ...over,
  };
}

test("retentionDays: 0, null, negative, NaN mean keep forever", () => {
  assert.equal(retentionDays(0), null);
  assert.equal(retentionDays(null), null);
  assert.equal(retentionDays(undefined), null);
  assert.equal(retentionDays(-5), null);
  assert.equal(retentionDays(Number.NaN), null);
  assert.equal(retentionDays("365"), null);
  assert.equal(retentionDays(365), 365);
  assert.equal(retentionDays(365.9), 365);
});

test("cutoff uses UTC days, unaffected by a DST change in the window", () => {
  // 2026-03-08 (US spring forward) lies inside this 400-day window.
  const now = Date.parse("2026-11-08T03:00:00Z");
  assert.equal(cutoffMs(now, 400), now - 400 * DAY_MS);
  assert.equal(iso(cutoffMs(now, 365)), "2025-11-08T03:00:00.000Z");
});

test("exactly at the cutoff is kept, one millisecond older is removed", () => {
  const cutoff = cutoffMs(NOW, 365);
  const at = { id: "a", is_archived: true, archived_at: iso(cutoff) };
  const older = { id: "b", is_archived: true, archived_at: iso(cutoff - 1) };
  const newer = { id: "c", is_archived: true, archived_at: iso(cutoff + 1) };
  const r = selectExpiredJobs([at, older, newer], cutoff);
  assert.deepEqual(r.map((x) => x.job.id), ["b"]);
});

test("job reference: archived_at, then updated_at; null dates are skipped", () => {
  assert.equal(
    jobReferenceMs({
      id: "a",
      is_archived: true,
      archived_at: "2024-01-01T00:00:00Z",
      updated_at: "2025-01-01T00:00:00Z",
    }),
    Date.parse("2024-01-01T00:00:00Z"),
  );
  assert.equal(
    jobReferenceMs({
      id: "a",
      is_archived: true,
      archived_at: null,
      updated_at: "2025-01-01T00:00:00Z",
    }),
    Date.parse("2025-01-01T00:00:00Z"),
  );
  assert.equal(
    jobReferenceMs({ id: "a", is_archived: true, archived_at: null }),
    null,
  );
  assert.equal(
    jobReferenceMs({ id: "a", is_archived: true, archived_at: "garbage" }),
    null,
  );
});

test("completed jobs age from completed_at; includeCompleted=false ignores them", () => {
  const job = {
    id: "a",
    is_completed: true,
    completed_at: "2020-01-01T00:00:00Z",
  };
  assert.equal(jobReferenceMs(job), Date.parse("2020-01-01T00:00:00Z"));
  assert.equal(jobReferenceMs(job, { includeCompleted: false }), null);
  // An open job is never touched, however old.
  assert.equal(
    jobReferenceMs({ id: "o", is_completed: false, updated_at: "2000-01-01" }),
    null,
  );
});

test("storagePathsForJob matches photos, signatures and the maintenance pdf only", () => {
  const objs = [
    { name: `photos/maintenance/${ID}/p1.jpg`, created_at: null },
    { name: `photos/maintenance/${ID}-other/p1.jpg`, created_at: null },
    { name: `photos/inspection/${ID}/p1.jpg`, created_at: null },
    { name: `signatures/maintenance/${ID}_technician.png`, created_at: null },
    { name: `signatures/inspections/${ID}.png`, created_at: null },
    { name: "pdfs/maintenance/Maintenance_S1_2025-01-01_0a1b2c3d.pdf", created_at: null },
    { name: "pdfs/maintenance/Maintenance_S1_2025-01-01_ffffffff.pdf", created_at: null },
    { name: "pdfs/inspections/S1/inspection_0a1b2c3d.pdf", created_at: null },
  ];
  assert.deepEqual(storagePathsForJob(ID, objs), [
    `photos/maintenance/${ID}/p1.jpg`,
    `signatures/maintenance/${ID}_technician.png`,
    "pdfs/maintenance/Maintenance_S1_2025-01-01_0a1b2c3d.pdf",
  ]);
  assert.deepEqual(storagePathsForJob("", objs), []);
});

test("selectExpiredReports: prefix, .pdf only, null created_at skipped, strict cutoff", () => {
  const cutoff = cutoffMs(NOW, 365);
  const objs = [
    { name: "pdfs/inspections/a.pdf", created_at: iso(cutoff - 1) },
    { name: "pdfs/inspections/at.pdf", created_at: iso(cutoff) },
    { name: "pdfs/inspections/new.pdf", created_at: iso(NOW) },
    { name: "pdfs/inspections/null.pdf", created_at: null },
    { name: "pdfs/inspections/bad.pdf", created_at: "nope" },
    { name: "pdfs/inspections/note.txt", created_at: iso(cutoff - 1) },
    { name: "photos/x.pdf", created_at: iso(cutoff - 1) },
    { name: "pdfs/UP.PDF", created_at: iso(cutoff - 5) },
  ];
  assert.deepEqual(selectExpiredReports(objs, ["pdfs/"], cutoff), [
    "pdfs/UP.PDF",
    "pdfs/inspections/a.pdf",
  ]);
  assert.deepEqual(selectExpiredReports(objs, [], cutoff), []);
  assert.deepEqual(selectExpiredReports(objs, [""], cutoff), []);
});

test("planTenant: 0 / null days remove nothing", () => {
  const old = iso(NOW - 3000 * DAY_MS);
  const base = input({
    jobs: [{ id: ID, is_archived: true, archived_at: old }],
    reportObjects: [{ name: "pdfs/a.pdf", created_at: old }],
  });
  for (const policy of [
    { archived_maintenance_days: 0, generated_report_days: 0 },
    { archived_maintenance_days: null, generated_report_days: null },
    {},
  ]) {
    const p = planTenant({ ...base, policy });
    assert.equal(p.jobs.length, 0);
    assert.equal(p.reportPaths.length, 0);
    assert.equal(p.archivedCutoff, null);
    assert.equal(p.reportCutoff, null);
  }
});

test("planTenant: collects job files and attachment rows, never inspections", () => {
  const old = iso(NOW - 800 * DAY_MS);
  const p = planTenant(
    input({
      policy: { archived_maintenance_days: 365, generated_report_days: null },
      jobs: [
        { id: ID, is_archived: true, archived_at: old },
        { id: "recent", is_archived: true, archived_at: iso(NOW - DAY_MS) },
      ],
      attachments: [
        { id: "att1", job_id: ID, bucket_name: "voltcore-files", file_path: "custom/x.pdf" },
        { id: "att2", job_id: ID, bucket_name: "other-bucket", file_path: "o/y.pdf" },
        { id: "att3", job_id: "recent", bucket_name: "voltcore-files", file_path: "z.pdf" },
      ],
      maintenanceObjects: [
        { name: `photos/maintenance/${ID}/p1.jpg`, created_at: old },
        { name: "pdfs/inspections/keep.pdf", created_at: old },
      ],
    }),
  );
  assert.equal(p.jobs.length, 1);
  assert.deepEqual(p.jobs[0].paths.sort(), [
    "custom/x.pdf",
    `photos/maintenance/${ID}/p1.jpg`,
  ]);
  assert.deepEqual(p.jobs[0].attachmentIds, ["att1"]);
  assert.equal(p.objectCount, 2);
  assert.equal(p.reportPaths.length, 0);
});

test("planTenant: a path claimed by a job is not counted again as a report", () => {
  const old = iso(NOW - 800 * DAY_MS);
  const pdf = "pdfs/maintenance/Maintenance_S1_2024-01-01_0a1b2c3d.pdf";
  const p = planTenant(
    input({
      jobs: [{ id: ID, is_archived: true, archived_at: old }],
      maintenanceObjects: [{ name: pdf, created_at: old }],
      reportObjects: [{ name: pdf, created_at: old }],
    }),
  );
  assert.deepEqual(p.jobs[0].paths, [pdf]);
  assert.deepEqual(p.reportPaths, []);
  assert.equal(p.objectCount, 1);
});

test("planTenant: cap trims reports and defers jobs that do not fit", () => {
  const old = iso(NOW - 800 * DAY_MS);
  const reports = Array.from({ length: 10 }, (_, i) => ({
    name: `pdfs/inspections/r${String(i).padStart(2, "0")}.pdf`,
    created_at: old,
  }));
  const capped = planTenant(
    input({
      policy: { archived_maintenance_days: null, generated_report_days: 365 },
      reportObjects: reports,
      budget: 4,
    }),
  );
  assert.equal(capped.reportPaths.length, 4);
  assert.equal(capped.capped, true);

  const exact = planTenant(
    input({
      policy: { archived_maintenance_days: null, generated_report_days: 365 },
      reportObjects: reports,
      budget: 10,
    }),
  );
  assert.equal(exact.reportPaths.length, 10);
  assert.equal(exact.capped, false);

  // A job with 3 files cannot fit in a budget of 2; a 1-file job still does.
  const big = "aaaaaaaa-0000-0000-0000-000000000001";
  const small = "bbbbbbbb-0000-0000-0000-000000000002";
  const p = planTenant(
    input({
      policy: { archived_maintenance_days: 365, generated_report_days: null },
      jobs: [
        { id: big, is_archived: true, archived_at: iso(NOW - 900 * DAY_MS) },
        { id: small, is_archived: true, archived_at: iso(NOW - 800 * DAY_MS) },
      ],
      maintenanceObjects: [
        { name: `photos/maintenance/${big}/1.jpg`, created_at: old },
        { name: `photos/maintenance/${big}/2.jpg`, created_at: old },
        { name: `photos/maintenance/${big}/3.jpg`, created_at: old },
        { name: `photos/maintenance/${small}/1.jpg`, created_at: old },
      ],
      budget: 2,
    }),
  );
  assert.deepEqual(p.jobs.map((j) => j.id), [small]);
  assert.equal(p.capped, true);
  // 3 files exceed even the whole budget of 2, so it is flagged as oversize.
  assert.deepEqual(p.oversizeJobIds, [big]);

  const zero = planTenant(
    input({
      policy: { archived_maintenance_days: null, generated_report_days: 365 },
      reportObjects: reports,
      budget: 0,
    }),
  );
  assert.equal(zero.reportPaths.length, 0);
  assert.equal(zero.capped, true);
});

test("planTenant: oversize job is reported when it exceeds the whole budget", () => {
  const old = iso(NOW - 800 * DAY_MS);
  const p = planTenant(
    input({
      policy: { archived_maintenance_days: 365, generated_report_days: null },
      jobs: [{ id: ID, is_archived: true, archived_at: old }],
      maintenanceObjects: [
        { name: `photos/maintenance/${ID}/1.jpg`, created_at: old },
        { name: `photos/maintenance/${ID}/2.jpg`, created_at: old },
      ],
      budget: 1,
    }),
  );
  assert.deepEqual(p.jobs, []);
  assert.deepEqual(p.oversizeJobIds, [ID]);
});

test("chunk splits into batches", () => {
  const items = Array.from({ length: 250 }, (_, i) => i);
  const c = chunk(items, 100);
  assert.deepEqual(c.map((x) => x.length), [100, 100, 50]);
  assert.deepEqual(chunk([], 100), []);
});

test("walkStorage recurses folders, pages, and honors the object cap", async () => {
  const tree: Record<string, ListEntry[]> = {
    "pdfs": [
      { name: "inspections", id: null, created_at: null },
      { name: "top.pdf", id: "1", created_at: "2020-01-01T00:00:00Z" },
    ],
    "pdfs/inspections": [
      { name: "S1", id: null, created_at: null },
      { name: "a.pdf", id: "2", created_at: "2020-01-02T00:00:00Z" },
      { name: "b.pdf", id: "3", created_at: "2020-01-03T00:00:00Z" },
    ],
    "pdfs/inspections/S1": [
      { name: "c.pdf", id: "4", created_at: "2020-01-04T00:00:00Z" },
    ],
  };
  const calls: Array<[string, number, number]> = [];
  const list = (prefix: string, offset: number, limit: number) => {
    calls.push([prefix, offset, limit]);
    return Promise.resolve((tree[prefix] ?? []).slice(offset, offset + limit));
  };
  const all = await walkStorage(list, "pdfs/", { maxObjects: 100, pageSize: 2 });
  assert.deepEqual(all.objects.map((o) => o.name).sort(), [
    "pdfs/inspections/S1/c.pdf",
    "pdfs/inspections/a.pdf",
    "pdfs/inspections/b.pdf",
    "pdfs/top.pdf",
  ]);
  assert.equal(all.truncated, false);
  // Paging happened (page size 2, 3 entries in one folder).
  assert.ok(calls.some(([p, o]) => p === "pdfs/inspections" && o === 2));

  const cut = await walkStorage(list, "pdfs", { maxObjects: 2, pageSize: 2 });
  assert.equal(cut.objects.length, 2);
  assert.equal(cut.truncated, true);
});
