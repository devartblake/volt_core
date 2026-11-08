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
  for (const role of ["technician", "supervisor", "dispatcher", "admin"]) {
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
