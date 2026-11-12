// Pure composer for the daily digest email. Plain data in, {subject, text, html}
// out (or null when there is nothing to say). No Deno or network imports.
//
// The HTML is plain: no images, no scripts, inline styles only. Every value that
// came from the database is HTML-escaped.

export const MAX_ITEMS = 10;
const NAVY = "#103078";

export type DigestData = {
  overdueTasks: Array<{ title: string; siteCode: string; dueDate: string }>;
  /** Site codes whose latest inspection is Red. */
  redSites: string[];
  overdueInspections: Array<{
    siteCode: string;
    dueDate: string;
    estimated: boolean;
  }>;
  stockAlerts: Array<{
    partNumber: string;
    name: string;
    onHand: number;
    minStock: number;
    kind: "out" | "low";
  }>;
  overduePurchaseOrders: Array<{
    poNumber: string;
    expectedOn: string;
    status: string;
  }>;
  followUps: Array<{ title: string; siteCode: string }>;
};

export type ComposeInput = {
  tenantName: string;
  /** The run time, epoch ms; only the UTC date is used. */
  nowMs: number;
  data: DigestData;
};

export type Composed = { subject: string; text: string; html: string };

type Section = {
  heading: string;
  /** One-line plain-language summary shown under the heading. */
  summary: string;
  columns: string[];
  rows: string[][];
  extra: number;
};

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

/** Collapse control characters and line breaks so a value stays on one line. */
function oneLine(value: string): string {
  // deno-lint-ignore no-control-regex
  return value.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
}

function plural(n: number, one: string, many: string): string {
  return n === 1 ? one : many;
}

function cut<T>(items: T[]): { shown: T[]; extra: number } {
  return {
    shown: items.slice(0, MAX_ITEMS),
    extra: Math.max(0, items.length - MAX_ITEMS),
  };
}

export function buildSections(data: DigestData): Section[] {
  const sections: Section[] = [];

  if (data.overdueTasks.length > 0) {
    const n = data.overdueTasks.length;
    const { shown, extra } = cut(data.overdueTasks);
    sections.push({
      heading: "Overdue scheduled tasks",
      summary: `${n} scheduled ${plural(n, "task is", "tasks are")} past ` +
        `${plural(n, "its", "their")} date and not yet done.`,
      columns: ["Task", "Site", "Was due"],
      rows: shown.map((t) => [oneLine(t.title), oneLine(t.siteCode), t.dueDate]),
      extra,
    });
  }

  if (data.redSites.length > 0) {
    const n = data.redSites.length;
    const { shown, extra } = cut(data.redSites);
    sections.push({
      heading: "Sites graded Red",
      summary: `${n} ${plural(n, "site has", "sites have")} a Red grade on ` +
        `the latest inspection.`,
      columns: ["Site"],
      rows: shown.map((s) => [oneLine(s)]),
      extra,
    });
  }

  if (data.overdueInspections.length > 0) {
    const n = data.overdueInspections.length;
    const { shown, extra } = cut(data.overdueInspections);
    const anyEstimated = data.overdueInspections.some((i) => i.estimated);
    sections.push({
      heading: "Inspections overdue",
      summary: `${n} ${plural(n, "site is", "sites are")} past the next ` +
        `inspection due date.` +
        (anyEstimated
          ? " Where no due date is stored it is one year after the last inspection."
          : ""),
      columns: ["Site", "Was due"],
      rows: shown.map((i) => [oneLine(i.siteCode), i.dueDate]),
      extra,
    });
  }

  if (data.stockAlerts.length > 0) {
    const n = data.stockAlerts.length;
    const { shown, extra } = cut(data.stockAlerts);
    sections.push({
      heading: "Parts to reorder",
      summary: `${n} ${plural(n, "part is", "parts are")} out of stock or ` +
        `below the minimum.`,
      columns: ["Part", "Name", "On hand", "Minimum"],
      rows: shown.map((p) => [
        oneLine(p.partNumber),
        oneLine(p.name),
        p.kind === "out" ? "0 (out)" : String(p.onHand),
        String(p.minStock),
      ]),
      extra,
    });
  }

  if (data.overduePurchaseOrders.length > 0) {
    const n = data.overduePurchaseOrders.length;
    const { shown, extra } = cut(data.overduePurchaseOrders);
    sections.push({
      heading: "Purchase orders late",
      summary: `${n} open purchase ${plural(n, "order is", "orders are")} ` +
        `past the expected delivery date.`,
      columns: ["Order", "Status", "Expected"],
      rows: shown.map((o) => [oneLine(o.poNumber), o.status, o.expectedOn]),
      extra,
    });
  }

  if (data.followUps.length > 0) {
    const n = data.followUps.length;
    const { shown, extra } = cut(data.followUps);
    sections.push({
      heading: "Maintenance follow-ups open",
      summary: `${n} maintenance ${plural(n, "job needs", "jobs need")} a ` +
        `follow-up and ${plural(n, "is", "are")} not completed.`,
      columns: ["Job", "Site"],
      rows: shown.map((f) => [oneLine(f.title), oneLine(f.siteCode)]),
      extra,
    });
  }

  return sections;
}

function utcDate(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

/** Returns null when every section is empty (caller skips the tenant). */
export function composeDigest(input: ComposeInput): Composed | null {
  const sections = buildSections(input.data);
  if (sections.length === 0) return null;

  const date = utcDate(input.nowMs);
  const subject = `Volt Core daily summary - ${date}`;
  const tenant = oneLine(input.tenantName);

  // ---- text ----
  const t: string[] = [];
  t.push(`Volt Core daily summary - ${date}`);
  if (tenant) t.push(tenant);
  t.push("");
  for (const s of sections) {
    t.push(s.heading.toUpperCase());
    t.push(s.summary);
    for (const r of s.rows) t.push(`  - ${r.filter((c) => c !== "").join(" | ")}`);
    if (s.extra > 0) t.push(`  ...and ${s.extra} more`);
    t.push("");
  }
  t.push("Sent automatically each morning (UTC dates). Open Volt Core for details.");
  const text = t.join("\n");

  // ---- html ----
  const th =
    'style="text-align:left;padding:4px 10px 4px 0;border-bottom:1px solid #c8cfdb;font-weight:bold;"';
  const td = 'style="padding:4px 10px 4px 0;border-bottom:1px solid #e6e9ef;"';
  const h: string[] = [];
  h.push(
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:14px;color:#1c2330;max-width:640px;">',
  );
  h.push(
    `<h1 style="color:${NAVY};font-size:20px;margin:0 0 4px 0;">Volt Core daily summary</h1>`,
  );
  h.push(
    `<p style="margin:0 0 16px 0;color:#4a5568;">${escapeHtml(date)}${
      tenant ? " - " + escapeHtml(tenant) : ""
    }</p>`,
  );
  for (const s of sections) {
    h.push(
      `<h2 style="color:${NAVY};font-size:16px;margin:20px 0 4px 0;">${escapeHtml(s.heading)}</h2>`,
    );
    h.push(`<p style="margin:0 0 8px 0;">${escapeHtml(s.summary)}</p>`);
    h.push('<table style="border-collapse:collapse;font-size:14px;">');
    h.push(
      "<tr>" +
        s.columns.map((c) => `<th ${th}>${escapeHtml(c)}</th>`).join("") +
        "</tr>",
    );
    for (const r of s.rows) {
      h.push(
        "<tr>" + r.map((c) => `<td ${td}>${escapeHtml(c)}</td>`).join("") +
          "</tr>",
      );
    }
    h.push("</table>");
    if (s.extra > 0) {
      h.push(`<p style="margin:6px 0 0 0;color:#4a5568;">...and ${s.extra} more</p>`);
    }
  }
  h.push(
    '<p style="margin:24px 0 0 0;color:#4a5568;font-size:12px;">Sent automatically each morning (UTC dates). Open Volt Core for details.</p>',
  );
  h.push("</div>");
  const html = h.join("\n");

  return { subject, text, html };
}
