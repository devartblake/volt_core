// Pure helpers shared by the cron-called functions (no Deno or network imports).
//
// The cron functions are deployed with --no-verify-jwt, so they must do their
// own caller check: either the service role key as a Bearer token, or the
// shared secret in the `x-cron-secret` header. Both comparisons are constant
// time so response timing does not leak how many leading characters matched.

/** Constant-time string equality. Different lengths still compare every byte. */
export function timingSafeEqualStr(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  const len = Math.max(x.length, y.length);
  let diff = x.length ^ y.length;
  for (let i = 0; i < len; i++) {
    diff |= (i < x.length ? x[i] : 0) ^ (i < y.length ? y[i] : 0);
  }
  return diff === 0;
}

export type CronAuthInput = {
  /** Value of the `x-cron-secret` request header, if any. */
  cronSecretHeader: string | null | undefined;
  /** Value of the `Authorization` request header, if any. */
  authorizationHeader: string | null | undefined;
  /** CRON_SECRET function secret. Unset or empty disables the header path. */
  cronSecret: string | null | undefined;
  /** SUPABASE_SERVICE_ROLE_KEY (injected by Supabase). */
  serviceRoleKey: string | null | undefined;
};

/** True only for the service role key or the exact shared cron secret. */
export function isCronAuthorized(input: CronAuthInput): boolean {
  const secret = input.cronSecret ?? "";
  const key = input.serviceRoleKey ?? "";

  const headerValue = input.cronSecretHeader ?? "";
  const headerOk = secret.length > 0 &&
    timingSafeEqualStr(headerValue, secret);

  const auth = input.authorizationHeader ?? "";
  const m = /^Bearer\s+(.+)$/i.exec(auth.trim());
  const token = m ? m[1].trim() : "";
  const bearerOk = key.length > 0 && timingSafeEqualStr(token, key);

  // Evaluate both before combining so neither path short-circuits the other.
  return headerOk || bearerOk;
}

/** dryRun defaults to TRUE; only an explicit boolean false turns it off. */
export function parseDryRun(body: unknown): boolean {
  if (body && typeof body === "object" && "dryRun" in body) {
    return (body as { dryRun?: unknown }).dryRun !== false;
  }
  return true;
}
