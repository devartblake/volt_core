// Pure input validation for invite-user. No Deno or network APIs here so it
// can be unit tested with `node --experimental-strip-types --test`.
// The Dart mirror lives in lib/modules/admin/domain/invite_validator.dart.

export const ALLOWED_ROLES = [
  "technician",
  "supervisor",
  "dispatcher",
  "admin",
] as const;

export type InviteRole = (typeof ALLOWED_ROLES)[number];

export interface InviteInput {
  email: string;
  displayName: string;
  role: InviteRole;
  phone: string | null;
  redirectTo: string | null;
  tenantId: string | null;
}

export type ValidationResult =
  | { ok: true; value: InviteInput }
  | { ok: false; message: string };

const EMAIL_RE = /^[^\s@,;<>()"]+@[^\s@,;<>()"]+\.[^\s@,;<>()"]+$/;
const PHONE_RE = /^[0-9+\-() ]+$/;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const MAX_EMAIL = 254;
export const MAX_NAME = 80;
export const MAX_PHONE = 30;

function fail(message: string): ValidationResult {
  return { ok: false, message };
}

export function isInviteRole(value: unknown): value is InviteRole {
  return typeof value === "string" &&
    (ALLOWED_ROLES as readonly string[]).includes(value);
}

export function validateInvite(body: unknown): ValidationResult {
  if (body === null || typeof body !== "object" || Array.isArray(body)) {
    return fail("Request body must be a JSON object.");
  }
  const b = body as Record<string, unknown>;

  if (typeof b.email !== "string") return fail("Enter an email address.");
  const email = b.email.trim().toLowerCase();
  if (email.length === 0) return fail("Enter an email address.");
  if (email.length > MAX_EMAIL || !EMAIL_RE.test(email)) {
    return fail("Enter a valid email address.");
  }
  const at = email.indexOf("@");
  const domain = email.slice(at + 1);
  if (domain.startsWith(".") || domain.endsWith(".") || domain.includes("..")) {
    return fail("Enter a valid email address.");
  }

  if (typeof b.displayName !== "string") return fail("Enter a name.");
  const displayName = b.displayName.trim();
  if (displayName.length < 1) return fail("Enter a name.");
  if (displayName.length > MAX_NAME) {
    return fail(`Name must be ${MAX_NAME} characters or fewer.`);
  }

  if (!isInviteRole(b.role)) {
    return fail("Choose a role: technician, supervisor, dispatcher or admin.");
  }

  let phone: string | null = null;
  if (b.phone !== undefined && b.phone !== null) {
    if (typeof b.phone !== "string") return fail("Phone number is not valid.");
    const p = b.phone.trim();
    if (p.length > 0) {
      if (p.length > MAX_PHONE || !PHONE_RE.test(p) || !/[0-9]/.test(p)) {
        return fail(
          "Phone may only contain digits, spaces and + - ( ).",
        );
      }
      phone = p;
    }
  }

  let redirectTo: string | null = null;
  if (b.redirectTo !== undefined && b.redirectTo !== null) {
    if (typeof b.redirectTo !== "string") {
      return fail("Redirect address is not valid.");
    }
    const r = b.redirectTo.trim();
    if (r.length > 0) {
      let url: URL;
      try {
        url = new URL(r);
      } catch {
        return fail("Redirect address is not valid.");
      }
      if (url.protocol !== "https:" && url.protocol !== "http:") {
        return fail("Redirect address is not valid.");
      }
      redirectTo = r;
    }
  }

  let tenantId: string | null = null;
  if (b.tenantId !== undefined && b.tenantId !== null) {
    if (typeof b.tenantId !== "string" || !UUID_RE.test(b.tenantId)) {
      return fail("Tenant id is not valid.");
    }
    tenantId = b.tenantId.toLowerCase();
  }

  return {
    ok: true,
    value: { email, displayName, role: b.role, phone, redirectTo, tenantId },
  };
}
