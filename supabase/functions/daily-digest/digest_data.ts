// Pure data selection for the daily digest. Plain arrays in, plain arrays out;
// no Deno, network or Supabase imports (unit-tested with Node).
//
// All dates are UTC. "Today" means the UTC calendar day of `nowMs`.

export const DAY_MS = 24 * 60 * 60 * 1000;
/** Same default as the app's readiness rules (staleInspectionDays). */
export const STALE_INSPECTION_DAYS = 365;

export function parseMs(value: string | null | undefined): number | null {
  if (typeof value !== "string" || value.trim() === "") return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

/** Start of the UTC day containing nowMs. */
export function startOfUtcDay(nowMs: number): number {
  return Math.floor(nowMs / DAY_MS) * DAY_MS;
}

/** YYYY-MM-DD in UTC. */
export function utcDate(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

// ---- schedule tasks --------------------------------------------------------

export type TaskRow = {
  id: string;
  title?: string | null;
  site_code?: string | null;
  status?: string | null;
  scheduled_date?: string | null;
  schedule_at?: string | null;
};

export type OverdueTask = { title: string; siteCode: string; dueDate: string };

/** Scheduled (or already flagged overdue) tasks whose date is before now. */
export function overdueTasks(rows: TaskRow[], nowMs: number): OverdueTask[] {
  const out: Array<OverdueTask & { ms: number }> = [];
  for (const r of rows) {
    const status = (r.status ?? "").toLowerCase();
    if (status !== "scheduled" && status !== "overdue") continue;
    const ms = parseMs(r.scheduled_date) ?? parseMs(r.schedule_at);
    if (ms === null || ms >= nowMs) continue;
    out.push({
      title: (r.title ?? "").trim() || "Scheduled task",
      siteCode: (r.site_code ?? "").trim(),
      dueDate: utcDate(ms),
      ms,
    });
  }
  out.sort((a, b) => a.ms - b.ms || a.title.localeCompare(b.title));
  return out.map(({ title, siteCode, dueDate }) => ({ title, siteCode, dueDate }));
}

// ---- inspections -----------------------------------------------------------

export type InspectionRow = {
  id: string;
  site_code?: string | null;
  site_grade?: string | null;
  service_date?: string | null;
  status?: string | null;
  /** From payload->>next_due_at when the app ever stores it (it does not yet). */
  next_due_at?: string | null;
};

/** Newest inspection per site (case-insensitive site code); blanks skipped. */
export function latestBySite(rows: InspectionRow[]): InspectionRow[] {
  const best = new Map<string, { row: InspectionRow; ms: number }>();
  for (const r of rows) {
    const code = (r.site_code ?? "").trim();
    if (code === "") continue;
    const status = (r.status ?? "").toLowerCase();
    if (status === "cancelled" || status === "archived") continue;
    const ms = parseMs(r.service_date);
    if (ms === null) continue;
    const k = code.toLowerCase();
    const cur = best.get(k);
    if (!cur || ms > cur.ms || (ms === cur.ms && r.id > cur.row.id)) {
      best.set(k, { row: r, ms });
    }
  }
  return Array.from(best.values()).map((v) => v.row);
}

/** Site codes whose latest inspection is graded Red, sorted. */
export function redSites(rows: InspectionRow[]): string[] {
  return latestBySite(rows)
    .filter((r) => (r.site_grade ?? "").trim().toLowerCase() === "red")
    .map((r) => (r.site_code ?? "").trim())
    .sort((a, b) => a.localeCompare(b));
}

export type OverdueInspection = {
  siteCode: string;
  dueDate: string;
  /** True when no stored next-due date existed and service date + 365 days was used. */
  estimated: boolean;
};

/**
 * Sites whose latest inspection is past its next-due date, most overdue first.
 * Uses next_due_at when present, otherwise service date + staleDays (calendar
 * arithmetic on UTC days). Due today is not overdue.
 */
export function overdueInspections(
  rows: InspectionRow[],
  nowMs: number,
  staleDays: number = STALE_INSPECTION_DAYS,
): OverdueInspection[] {
  const today = startOfUtcDay(nowMs);
  const out: Array<OverdueInspection & { ms: number }> = [];
  for (const r of latestBySite(rows)) {
    const stored = parseMs(r.next_due_at);
    let due: number;
    let estimated = false;
    if (stored !== null) {
      due = startOfUtcDay(stored);
    } else {
      due = startOfUtcDay(parseMs(r.service_date) as number) + staleDays * DAY_MS;
      estimated = true;
    }
    if (due >= today) continue;
    out.push({
      siteCode: (r.site_code ?? "").trim(),
      dueDate: utcDate(due),
      estimated,
      ms: due,
    });
  }
  out.sort((a, b) => a.ms - b.ms || a.siteCode.localeCompare(b.siteCode));
  return out.map(({ siteCode, dueDate, estimated }) => ({
    siteCode,
    dueDate,
    estimated,
  }));
}

// ---- parts -----------------------------------------------------------------

export type PartRow = {
  id: string;
  part_number?: string | null;
  name?: string | null;
  min_stock?: number | null;
  is_active?: boolean | null;
};
export type StockRow = { part_id: string; on_hand?: number | null };

export type StockAlert = {
  partNumber: string;
  name: string;
  onHand: number;
  minStock: number;
  kind: "out" | "low";
};

/**
 * Parts that are out of stock (on hand <= 0) or below min_stock. Only parts the
 * company actually tracks are considered: min_stock > 0, or at least one stock
 * row. Otherwise a catalog of never-stocked parts would all read "out of stock".
 */
export function stockAlerts(parts: PartRow[], stock: StockRow[]): StockAlert[] {
  const onHand = new Map<string, number>();
  for (const s of stock) {
    onHand.set(s.part_id, (onHand.get(s.part_id) ?? 0) + (s.on_hand ?? 0));
  }
  const out: StockAlert[] = [];
  for (const p of parts) {
    if (p.is_active === false) continue;
    const min = p.min_stock ?? 0;
    const tracked = min > 0 || onHand.has(p.id);
    if (!tracked) continue;
    const have = onHand.get(p.id) ?? 0;
    let kind: "out" | "low" | null = null;
    if (have <= 0) kind = "out";
    else if (have < min) kind = "low";
    if (kind === null) continue;
    out.push({
      partNumber: (p.part_number ?? "").trim(),
      name: (p.name ?? "").trim(),
      onHand: have,
      minStock: min,
      kind,
    });
  }
  // Out of stock first, then by part number.
  out.sort((a, b) =>
    (a.kind === b.kind ? 0 : a.kind === "out" ? -1 : 1) ||
    a.partNumber.localeCompare(b.partNumber)
  );
  return out;
}

// ---- purchase orders -------------------------------------------------------

export type PoRow = {
  id: string;
  po_number?: string | null;
  status?: string | null;
  /** date, YYYY-MM-DD */
  expected_on?: string | null;
};
export type OverduePo = { poNumber: string; expectedOn: string; status: string };

/** Sent or partial orders whose expected date is before today (UTC). */
export function overduePurchaseOrders(rows: PoRow[], nowMs: number): OverduePo[] {
  const today = utcDate(nowMs);
  const out: OverduePo[] = [];
  for (const r of rows) {
    const status = (r.status ?? "").toLowerCase();
    if (status !== "sent" && status !== "partial") continue;
    const d = (r.expected_on ?? "").slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) continue;
    if (d >= today) continue;
    out.push({ poNumber: (r.po_number ?? "").trim(), expectedOn: d, status });
  }
  out.sort((a, b) =>
    a.expectedOn.localeCompare(b.expectedOn) ||
    a.poNumber.localeCompare(b.poNumber)
  );
  return out;
}

// ---- maintenance follow-ups ------------------------------------------------

export type JobRow = {
  id: string;
  title?: string | null;
  site_code?: string | null;
  requires_follow_up?: boolean | null;
  is_completed?: boolean | null;
  is_archived?: boolean | null;
};
export type FollowUp = { title: string; siteCode: string };

export function openFollowUps(rows: JobRow[]): FollowUp[] {
  const out: FollowUp[] = [];
  for (const r of rows) {
    if (r.requires_follow_up !== true) continue;
    if (r.is_completed === true || r.is_archived === true) continue;
    out.push({
      title: (r.title ?? "").trim() || "Maintenance job",
      siteCode: (r.site_code ?? "").trim(),
    });
  }
  out.sort((a, b) =>
    a.siteCode.localeCompare(b.siteCode) || a.title.localeCompare(b.title)
  );
  return out;
}

// ---- recipients ------------------------------------------------------------

export type MemberRow = { user_id: string; role?: string | null; is_active?: boolean | null };
export type ProfileRow = {
  user_id: string;
  email?: string | null;
  is_active?: boolean | null;
  /** `daily_digest_opt_out` (migration 20261115100000); true = skip this person. */
  daily_digest_opt_out?: boolean | null;
};

const DIGEST_ROLES = new Set(["admin", "supervisor", "dispatcher"]);

/** Distinct, lower-cased emails of active admins/supervisors/dispatchers. */
export function digestRecipients(
  members: MemberRow[],
  profiles: ProfileRow[],
): string[] {
  const eligible = new Set(
    members
      .filter((m) =>
        m.is_active !== false && DIGEST_ROLES.has((m.role ?? "").toLowerCase())
      )
      .map((m) => m.user_id),
  );
  const emails = new Set<string>();
  for (const p of profiles) {
    if (!eligible.has(p.user_id)) continue;
    if (p.is_active === false) continue;
    if (p.daily_digest_opt_out === true) continue;
    const e = (p.email ?? "").trim().toLowerCase();
    if (/^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$/.test(e)) emails.add(e);
  }
  return Array.from(emails).sort();
}
