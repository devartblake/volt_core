import { test } from "node:test";
import assert from "node:assert/strict";
import {
  divisionUsable,
  emailDomain,
  isRateLimited,
  planMembership,
  rateLimitSince,
  resolveTenant,
} from "./plan.ts";

const T1 = "00000000-0000-0000-0000-000000000001";
const T2 = "00000000-0000-0000-0000-000000000002";

test("new user: create, previous role repeats new role", () => {
  assert.deepEqual(planMembership(null, "dispatcher"), {
    action: "create",
    previousRole: "dispatcher",
    newRole: "dispatcher",
  });
});

test("existing active member with other role: change_role", () => {
  const p = planMembership({ role: "technician", is_active: true }, "supervisor");
  assert.deepEqual(p, {
    action: "change_role",
    previousRole: "technician",
    newRole: "supervisor",
  });
});

test("same role active: unchanged (still recorded by caller)", () => {
  const p = planMembership({ role: "admin", is_active: true }, "admin");
  assert.equal(p.action, "unchanged");
  assert.equal(p.previousRole, "admin");
});

test("inactive member: reactivate keeps their old role as previous", () => {
  const p = planMembership({ role: "technician", is_active: false }, "technician");
  assert.equal(p.action, "reactivate");
  assert.equal(p.previousRole, "technician");
});

test("resolveTenant: single admin membership", () => {
  const r = resolveTenant([{ tenant_id: T1, role: "admin", is_active: true }], null);
  assert.deepEqual(r, { ok: true, tenantId: T1 });
});

test("resolveTenant: non-admin or inactive is forbidden", () => {
  for (const m of [
    { tenant_id: T1, role: "supervisor", is_active: true },
    { tenant_id: T1, role: "admin", is_active: false },
  ]) {
    const r = resolveTenant([m], null);
    assert.equal(r.ok, false);
    if (!r.ok) assert.equal(r.status, 403);
  }
  const none = resolveTenant([], null);
  assert.equal(none.ok === false && none.status, 403);
});

test("resolveTenant: requested tenant must be one the caller administers", () => {
  const ms = [
    { tenant_id: T1, role: "admin", is_active: true },
    { tenant_id: T2, role: "technician", is_active: true },
  ];
  const r = resolveTenant(ms, T2);
  assert.equal(r.ok === false && r.status, 403);
  assert.deepEqual(resolveTenant(ms, T1), { ok: true, tenantId: T1 });
});

test("resolveTenant: several admin tenants need a choice", () => {
  const ms = [
    { tenant_id: T1, role: "admin", is_active: true },
    { tenant_id: T2, role: "admin", is_active: true },
  ];
  const r = resolveTenant(ms, null);
  assert.equal(r.ok === false && r.status, 400);
  assert.deepEqual(resolveTenant(ms, T2.toUpperCase()), { ok: true, tenantId: T2 });
});

test("rate limit boundary is 20", () => {
  assert.equal(isRateLimited(19), false);
  assert.equal(isRateLimited(20), true);
  assert.equal(isRateLimited(21), true);
});

test("rateLimitSince is one hour back", () => {
  const now = Date.UTC(2026, 0, 1, 12);
  assert.equal(rateLimitSince(now), "2026-01-01T11:00:00.000Z");
});

test("emailDomain never exposes the local part", () => {
  assert.equal(emailDomain("ann@example.com"), "example.com");
  assert.equal(emailDomain("garbage"), "unknown");
});

test("apprentice plans like any other role", () => {
  assert.deepEqual(planMembership(null, "apprentice"), {
    action: "create",
    previousRole: "apprentice",
    newRole: "apprentice",
  });
  const p = planMembership({ role: "technician", is_active: true }, "apprentice");
  assert.equal(p.action, "change_role");
});

test("divisionUsable: must exist, be active and belong to the tenant", () => {
  const row = { id: "d1", tenant_id: T1, is_active: true };
  assert.equal(divisionUsable(row, T1), true);
  assert.equal(divisionUsable(row, T1.toUpperCase()), true);
  assert.equal(divisionUsable(row, T2), false);
  assert.equal(divisionUsable({ ...row, is_active: false }, T1), false);
  assert.equal(divisionUsable(null, T1), false);
  assert.equal(divisionUsable(undefined, T1), false);
});
