import { test } from "node:test";
import assert from "node:assert/strict";
import { buildSections, composeDigest, escapeHtml } from "./compose.ts";
import type { DigestData } from "./compose.ts";
import {
  digestRecipients,
  latestBySite,
  openFollowUps,
  overdueInspections,
  overduePurchaseOrders,
  overdueTasks,
  redSites,
  stockAlerts,
} from "./digest_data.ts";

const NOW = Date.parse("2026-11-08T12:00:00Z");

function empty(): DigestData {
  return {
    overdueTasks: [],
    redSites: [],
    overdueInspections: [],
    stockAlerts: [],
    overduePurchaseOrders: [],
    followUps: [],
  };
}

// ---- compose ---------------------------------------------------------------

test("empty data produces null", () => {
  assert.equal(composeDigest({ tenantName: "A&S", nowMs: NOW, data: empty() }), null);
});

test("each section appears only when it has data, in the documented order", () => {
  const cases: Array<[Partial<DigestData>, string]> = [
    [{ overdueTasks: [{ title: "T", siteCode: "Q_1", dueDate: "2026-11-01" }] }, "Overdue scheduled tasks"],
    [{ redSites: ["Q_1"] }, "Sites graded Red"],
    [{ overdueInspections: [{ siteCode: "Q_2", dueDate: "2026-01-01", estimated: false }] }, "Inspections overdue"],
    [{ stockAlerts: [{ partNumber: "P1", name: "Filter", onHand: 0, minStock: 2, kind: "out" }] }, "Parts to reorder"],
    [{ overduePurchaseOrders: [{ poNumber: "PO-1", expectedOn: "2026-11-01", status: "sent" }] }, "Purchase orders late"],
    [{ followUps: [{ title: "J", siteCode: "X_1" }] }, "Maintenance follow-ups open"],
  ];
  for (const [part, heading] of cases) {
    const out = composeDigest({ tenantName: "T", nowMs: NOW, data: { ...empty(), ...part } });
    assert.ok(out, heading);
    assert.deepEqual(buildSections({ ...empty(), ...part }).map((s) => s.heading), [heading]);
    assert.ok(out.text.includes(heading.toUpperCase()));
    assert.ok(out.html.includes(heading));
  }

  const all: DigestData = {
    overdueTasks: [{ title: "T", siteCode: "S", dueDate: "2026-11-01" }],
    redSites: ["R"],
    overdueInspections: [{ siteCode: "I", dueDate: "2026-01-01", estimated: true }],
    stockAlerts: [{ partNumber: "P", name: "N", onHand: 1, minStock: 5, kind: "low" }],
    overduePurchaseOrders: [{ poNumber: "PO", expectedOn: "2026-11-01", status: "partial" }],
    followUps: [{ title: "J", siteCode: "S" }],
  };
  assert.deepEqual(buildSections(all).map((s) => s.heading), [
    "Overdue scheduled tasks",
    "Sites graded Red",
    "Inspections overdue",
    "Parts to reorder",
    "Purchase orders late",
    "Maintenance follow-ups open",
  ]);
});

test("subject, navy heading, no images, plain tables", () => {
  const out = composeDigest({
    tenantName: "A&S Electric",
    nowMs: NOW,
    data: { ...empty(), redSites: ["Q_1"] },
  });
  assert.ok(out);
  assert.equal(out.subject, "Volt Core daily summary - 2026-11-08");
  assert.ok(out.html.includes("#103078"));
  assert.ok(out.html.includes("<table"));
  assert.ok(!/<img/i.test(out.html));
  assert.ok(!/<script/i.test(out.html));
  assert.ok(out.html.includes("A&amp;S Electric"));
  assert.ok(out.text.includes("A&S Electric"));
});

test("truncates to 10 and reports the rest, count stays the full count", () => {
  const sites = Array.from({ length: 13 }, (_, i) => `Q_${String(i).padStart(2, "0")}`);
  const out = composeDigest({ tenantName: "T", nowMs: NOW, data: { ...empty(), redSites: sites } });
  assert.ok(out);
  assert.ok(out.text.includes("13 sites have a Red grade"));
  assert.ok(out.text.includes("Q_09"));
  assert.ok(!out.text.includes("Q_10"));
  assert.ok(out.text.includes("...and 3 more"));
  assert.ok(out.html.includes("...and 3 more"));

  const ten = composeDigest({ tenantName: "T", nowMs: NOW, data: { ...empty(), redSites: sites.slice(0, 10) } });
  assert.ok(ten && !ten.text.includes("more"));
  const one = composeDigest({ tenantName: "T", nowMs: NOW, data: { ...empty(), redSites: ["Q_1"] } });
  assert.ok(one && one.text.includes("1 site has a Red grade"));
});

test("HTML escapes site names, titles and tenant name (XSS safe)", () => {
  const evil = '<script>alert("x")</script>&"\'';
  const out = composeDigest({
    tenantName: evil,
    nowMs: NOW,
    data: {
      ...empty(),
      redSites: [evil],
      overdueTasks: [{ title: evil, siteCode: evil, dueDate: "2026-11-01" }],
      stockAlerts: [{ partNumber: evil, name: evil, onHand: 0, minStock: 1, kind: "out" }],
      overduePurchaseOrders: [{ poNumber: evil, expectedOn: "2026-11-01", status: "sent" }],
      followUps: [{ title: evil, siteCode: evil }],
    },
  });
  assert.ok(out);
  assert.ok(!out.html.includes("<script"));
  assert.ok(!out.html.includes('alert("x")'));
  assert.ok(out.html.includes("&lt;script&gt;"));
  assert.equal(escapeHtml("<a href='x'>&</a>"), "&lt;a href=&#39;x&#39;&gt;&amp;&lt;/a&gt;");
});

test("line breaks in names stay on one line in the text body", () => {
  const out = composeDigest({
    tenantName: "T",
    nowMs: NOW,
    data: { ...empty(), redSites: ["Q_1\r\nBcc: x"] },
  });
  assert.ok(out);
  assert.ok(!/\r|Q_1\nBcc/.test(out.text));
});

// ---- data selection --------------------------------------------------------

test("overdueTasks: scheduled/overdue and past due only, oldest first", () => {
  const rows = [
    { id: "1", title: "New", status: "scheduled", scheduled_date: "2026-11-07T10:00:00Z" },
    { id: "2", title: "Old", status: "scheduled", scheduled_date: "2026-10-01T10:00:00Z" },
    { id: "3", title: "Future", status: "scheduled", scheduled_date: "2026-11-09T10:00:00Z" },
    { id: "4", title: "Done", status: "completed", scheduled_date: "2026-10-01T10:00:00Z" },
    { id: "5", title: "Flagged", status: "overdue", schedule_at: "2026-09-01T10:00:00Z" },
    { id: "6", title: "NoDate", status: "scheduled" },
    { id: "7", title: "Cancelled", status: "cancelled", scheduled_date: "2026-09-01T10:00:00Z" },
  ];
  assert.deepEqual(overdueTasks(rows, NOW).map((t) => t.title), ["Flagged", "Old", "New"]);
});

test("latestBySite keeps the newest per site, case-insensitive, skips blanks and cancelled", () => {
  const rows = [
    { id: "a", site_code: "Q_1", site_grade: "Red", service_date: "2025-01-01T00:00:00Z" },
    { id: "b", site_code: "q_1", site_grade: "Green", service_date: "2026-01-01T00:00:00Z" },
    { id: "c", site_code: "", site_grade: "Red", service_date: "2026-01-01T00:00:00Z" },
    { id: "d", site_code: "Q_2", site_grade: "Red", service_date: "2026-02-01T00:00:00Z" },
    { id: "e", site_code: "Q_2", site_grade: "Green", service_date: "2026-03-01T00:00:00Z", status: "cancelled" },
    { id: "f", site_code: "Q_3", site_grade: "Red", service_date: "bad" },
  ];
  assert.deepEqual(latestBySite(rows).map((r) => r.id).sort(), ["b", "d"]);
  // Q_1 improved to Green, so only Q_2 is Red.
  assert.deepEqual(redSites(rows), ["Q_2"]);
});

test("overdueInspections: stored date, estimated fallback, due today is not overdue", () => {
  const rows = [
    { id: "1", site_code: "A", service_date: "2025-01-01T00:00:00Z" }, // est. due 2026-01-01
    { id: "2", site_code: "B", service_date: "2026-06-01T00:00:00Z" }, // est. due 2027
    { id: "3", site_code: "C", service_date: "2026-01-01T00:00:00Z", next_due_at: "2026-11-07T23:00:00Z" },
    { id: "4", site_code: "D", service_date: "2026-01-01T00:00:00Z", next_due_at: "2026-11-08T01:00:00Z" },
    { id: "5", site_code: "E", service_date: "2026-01-01T00:00:00Z", next_due_at: "2026-12-01T00:00:00Z" },
  ];
  const r = overdueInspections(rows, NOW);
  assert.deepEqual(r.map((x) => x.siteCode), ["A", "C"]);
  assert.equal(r[0].estimated, true);
  assert.equal(r[0].dueDate, "2026-01-01");
  assert.equal(r[1].estimated, false);
});

test("overdueInspections uses the latest inspection only", () => {
  const rows = [
    { id: "1", site_code: "A", service_date: "2024-01-01T00:00:00Z" },
    { id: "2", site_code: "A", service_date: "2026-10-01T00:00:00Z" },
  ];
  assert.deepEqual(overdueInspections(rows, NOW), []);
});

test("stockAlerts: out, low, untracked and inactive parts", () => {
  const parts = [
    { id: "p1", part_number: "OUT", min_stock: 2 },
    { id: "p2", part_number: "LOW", min_stock: 5 },
    { id: "p3", part_number: "OK", min_stock: 5 },
    { id: "p4", part_number: "NEVER", min_stock: 0 },
    { id: "p5", part_number: "ZEROED", min_stock: 0 },
    { id: "p6", part_number: "OFF", min_stock: 5, is_active: false },
  ];
  const stock = [
    { part_id: "p2", on_hand: 2 },
    { part_id: "p3", on_hand: 4 },
    { part_id: "p3", on_hand: 3 }, // two locations sum to 7
    { part_id: "p5", on_hand: 0 },
  ];
  const r = stockAlerts(parts, stock);
  assert.deepEqual(r.map((x) => [x.partNumber, x.kind]), [
    ["OUT", "out"],
    ["ZEROED", "out"],
    ["LOW", "low"],
  ]);
});

test("overduePurchaseOrders: sent/partial and before today only", () => {
  const rows = [
    { id: "1", po_number: "A", status: "sent", expected_on: "2026-11-07" },
    { id: "2", po_number: "B", status: "partial", expected_on: "2026-10-01" },
    { id: "3", po_number: "C", status: "sent", expected_on: "2026-11-08" },
    { id: "4", po_number: "D", status: "received", expected_on: "2026-10-01" },
    { id: "5", po_number: "E", status: "draft", expected_on: "2026-10-01" },
    { id: "6", po_number: "F", status: "sent", expected_on: null },
    { id: "7", po_number: "G", status: "cancelled", expected_on: "2026-10-01" },
  ];
  assert.deepEqual(overduePurchaseOrders(rows, NOW).map((p) => p.poNumber), ["B", "A"]);
});

test("openFollowUps: flagged and not completed or archived", () => {
  const rows = [
    { id: "1", title: "Open", site_code: "B", requires_follow_up: true, is_completed: false },
    { id: "2", title: "Done", site_code: "A", requires_follow_up: true, is_completed: true },
    { id: "3", title: "NoFlag", site_code: "A", requires_follow_up: false },
    { id: "4", title: "Arch", site_code: "A", requires_follow_up: true, is_archived: true },
    { id: "5", title: "Open2", site_code: "A", requires_follow_up: true },
  ];
  assert.deepEqual(openFollowUps(rows).map((f) => f.title), ["Open2", "Open"]);
});

test("digestRecipients: roles, inactive members/profiles, opt-out, dedupe, bad emails", () => {
  const members = [
    { user_id: "u1", role: "admin", is_active: true },
    { user_id: "u2", role: "supervisor", is_active: true },
    { user_id: "u3", role: "dispatcher", is_active: true },
    { user_id: "u4", role: "technician", is_active: true },
    { user_id: "u5", role: "admin", is_active: false },
    { user_id: "u6", role: "admin", is_active: true },
    { user_id: "u7", role: "admin", is_active: true },
    { user_id: "u8", role: "admin", is_active: true },
  ];
  const profiles = [
    { user_id: "u1", email: "Boss@Example.test", is_active: true },
    { user_id: "u2", email: "boss@example.test", is_active: true }, // duplicate
    { user_id: "u3", email: "disp@example.test" },
    { user_id: "u4", email: "tech@example.test", is_active: true },
    { user_id: "u5", email: "gone@example.test", is_active: true },
    { user_id: "u6", email: "off@example.test", is_active: false },
    { user_id: "u7", email: "optout@example.test", is_active: true, daily_digest_opt_out: true },
    { user_id: "u8", email: "not an email", is_active: true },
    { user_id: "u9", email: "stranger@example.test", is_active: true },
  ];
  assert.deepEqual(digestRecipients(members, profiles), [
    "boss@example.test",
    "disp@example.test",
  ]);
});
