import { test } from "node:test";
import assert from "node:assert/strict";
import { validateInvite } from "./validate.ts";

const ok = { email: "A@B.com", displayName: "Ann", role: "technician" };

function bad(body: unknown, re?: RegExp) {
  const r = validateInvite(body);
  assert.equal(r.ok, false);
  if (!r.ok && re) assert.match(r.message, re);
}

test("accepts minimal input, trims and lowercases email", () => {
  const r = validateInvite({ ...ok, email: "  Ann@Example.COM " });
  assert.equal(r.ok, true);
  if (r.ok) {
    assert.equal(r.value.email, "ann@example.com");
    assert.equal(r.value.phone, null);
    assert.equal(r.value.redirectTo, null);
    assert.equal(r.value.tenantId, null);
  }
});

test("rejects non-objects", () => {
  for (const b of [null, undefined, 5, "x", [], true]) bad(b);
});

test("email rules", () => {
  for (const e of ["", "   ", "nope", "a@b", "a b@c.com", "a@b..com", "a@.com", "a@b.com.", "a@@b.com", "a,b@c.com"]) {
    bad({ ...ok, email: e });
  }
  bad({ ...ok, email: 5 });
  bad({ ...ok, email: undefined });
  bad({ ...ok, email: "a".repeat(250) + "@b.com" });
});

test("displayName 1-80 chars after trim", () => {
  bad({ ...ok, displayName: "" }, /name/i);
  bad({ ...ok, displayName: "   " }, /name/i);
  bad({ ...ok, displayName: 3 });
  bad({ ...ok, displayName: "x".repeat(81) }, /80/);
  const r = validateInvite({ ...ok, displayName: "  " + "x".repeat(80) + "  " });
  assert.equal(r.ok, true);
});

test("role must be in the allowed list", () => {
  for (const role of ["apprentice", "technician", "supervisor", "dispatcher", "admin"]) {
    assert.equal(validateInvite({ ...ok, role }).ok, true);
  }
  for (const role of ["tech", "Admin", "owner", "", null, undefined, 1, ["admin"]]) {
    bad({ ...ok, role });
  }
});

test("phone optional, limited charset", () => {
  assert.equal(validateInvite({ ...ok, phone: "+1 (555) 123-4567" }).ok, true);
  const empty = validateInvite({ ...ok, phone: "  " });
  assert.equal(empty.ok && empty.value.phone, null);
  assert.equal(validateInvite({ ...ok, phone: null }).ok, true);
  bad({ ...ok, phone: "555-abc" });
  bad({ ...ok, phone: "555;DROP" });
  bad({ ...ok, phone: "+-()" });
  bad({ ...ok, phone: 5551234 });
  bad({ ...ok, phone: "1".repeat(31) });
});

test("redirectTo must be an http(s) url when present", () => {
  assert.equal(validateInvite({ ...ok, redirectTo: "https://x.example/cb" }).ok, true);
  bad({ ...ok, redirectTo: "javascript:alert(1)" });
  bad({ ...ok, redirectTo: "not a url" });
  bad({ ...ok, redirectTo: 4 });
});

test("tenantId must be a uuid when present", () => {
  const id = "123E4567-E89B-12D3-A456-426614174000";
  const r = validateInvite({ ...ok, tenantId: id });
  assert.equal(r.ok && r.value.tenantId, id.toLowerCase());
  bad({ ...ok, tenantId: "1; drop" });
  bad({ ...ok, tenantId: 1 });
});

test("divisionId (older single form) is optional and must be a uuid", () => {
  const id = "123E4567-E89B-12D3-A456-426614174000";
  const r = validateInvite({ ...ok, divisionId: id });
  assert.deepEqual(r.ok && r.value.divisionIds, [id.toLowerCase()]);
  for (const empty of [undefined, null, ""]) {
    const e = validateInvite({ ...ok, divisionId: empty });
    assert.deepEqual(e.ok && e.value.divisionIds, []);
  }
  bad({ ...ok, divisionId: "not-a-uuid" });
  bad({ ...ok, divisionId: 7 });
  bad({ ...ok, divisionId: "1; drop table divisions" });
});

test("divisionIds: array of uuids, deduplicated, merged with divisionId", () => {
  const a = "123e4567-e89b-12d3-a456-426614174000";
  const b = "223e4567-e89b-12d3-a456-426614174000";
  let r = validateInvite({ ...ok, divisionIds: [a, b.toUpperCase(), a] });
  assert.deepEqual(r.ok && r.value.divisionIds, [a, b]);
  r = validateInvite({ ...ok, divisionId: a, divisionIds: [a, b] });
  assert.deepEqual(r.ok && r.value.divisionIds, [a, b]);
  for (const empty of [undefined, null, []]) {
    r = validateInvite({ ...ok, divisionIds: empty });
    assert.deepEqual(r.ok && r.value.divisionIds, []);
  }
});

test("divisionIds: rejects non-arrays, bad entries and more than 10", () => {
  const a = "123e4567-e89b-12d3-a456-426614174000";
  bad({ ...ok, divisionIds: a });
  bad({ ...ok, divisionIds: ["nope"] });
  bad({ ...ok, divisionIds: [a, 7] });
  bad({ ...ok, divisionIds: [{}] });
  const many = Array.from(
    { length: 11 },
    (_, i) => `123e4567-e89b-12d3-a456-4266141740${String(i).padStart(2, "0")}`,
  );
  bad({ ...ok, divisionIds: many });
  const ten = many.slice(0, 10);
  const r = validateInvite({ ...ok, divisionIds: ten });
  assert.equal(r.ok && r.value.divisionIds.length, 10);
});

test("apprentice is an allowed role", () => {
  const r = validateInvite({ ...ok, role: "apprentice" });
  assert.equal(r.ok && r.value.role, "apprentice");
});
