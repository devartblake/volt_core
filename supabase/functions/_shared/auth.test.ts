import { test } from "node:test";
import assert from "node:assert/strict";
import { isCronAuthorized, parseDryRun, timingSafeEqualStr } from "./auth.ts";

const base = {
  cronSecretHeader: null,
  authorizationHeader: null,
  cronSecret: "s3cret",
  serviceRoleKey: "svc-key",
};

test("timingSafeEqualStr", () => {
  assert.equal(timingSafeEqualStr("abc", "abc"), true);
  assert.equal(timingSafeEqualStr("abc", "abd"), false);
  assert.equal(timingSafeEqualStr("abc", "abcd"), false);
  assert.equal(timingSafeEqualStr("", ""), true);
});

test("accepts the cron secret header", () => {
  assert.equal(isCronAuthorized({ ...base, cronSecretHeader: "s3cret" }), true);
});

test("accepts the service role bearer token", () => {
  assert.equal(
    isCronAuthorized({ ...base, authorizationHeader: "Bearer svc-key" }),
    true,
  );
});

test("rejects wrong, missing and user tokens", () => {
  assert.equal(isCronAuthorized(base), false);
  assert.equal(isCronAuthorized({ ...base, cronSecretHeader: "nope" }), false);
  assert.equal(
    isCronAuthorized({ ...base, authorizationHeader: "Bearer user-jwt" }),
    false,
  );
  assert.equal(
    isCronAuthorized({ ...base, authorizationHeader: "svc-key" }),
    false,
  );
});

test("unset secrets never match an empty header", () => {
  assert.equal(
    isCronAuthorized({
      cronSecretHeader: "",
      authorizationHeader: "Bearer ",
      cronSecret: undefined,
      serviceRoleKey: undefined,
    }),
    false,
  );
  assert.equal(
    isCronAuthorized({
      cronSecretHeader: "",
      authorizationHeader: "",
      cronSecret: "",
      serviceRoleKey: "",
    }),
    false,
  );
});

test("parseDryRun defaults to true", () => {
  assert.equal(parseDryRun({}), true);
  assert.equal(parseDryRun(null), true);
  assert.equal(parseDryRun({ dryRun: "false" }), true);
  assert.equal(parseDryRun({ dryRun: true }), true);
  assert.equal(parseDryRun({ dryRun: false }), false);
});
