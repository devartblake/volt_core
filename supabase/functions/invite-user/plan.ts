// Pure decision logic for invite-user: which tenant, and what to write.

import type { InviteRole } from "./validate.ts";

export const INVITE_REASON = "Invited";
export const RATE_LIMIT_MAX = 20;
export const RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;

export interface Membership {
  tenant_id: string;
  role: string;
  is_active: boolean;
}

export type TenantChoice =
  | { ok: true; tenantId: string }
  | { ok: false; status: 403 | 400; message: string };

/**
 * The tenant is derived from the caller's own ACTIVE ADMIN memberships.
 * A tenant id in the request is only a tie-breaker and must be one of them.
 */
export function resolveTenant(
  memberships: Membership[],
  requestedTenantId: string | null,
): TenantChoice {
  const adminOf = memberships
    .filter((m) => m.is_active === true && m.role === "admin")
    .map((m) => m.tenant_id.toLowerCase());
  if (adminOf.length === 0) {
    return { ok: false, status: 403, message: "Only admins can invite people." };
  }
  if (requestedTenantId !== null) {
    if (!adminOf.includes(requestedTenantId.toLowerCase())) {
      return {
        ok: false,
        status: 403,
        message: "Only admins can invite people.",
      };
    }
    return { ok: true, tenantId: requestedTenantId.toLowerCase() };
  }
  if (adminOf.length > 1) {
    return {
      ok: false,
      status: 400,
      message: "You administer several companies. Choose which one.",
    };
  }
  return { ok: true, tenantId: adminOf[0] };
}

export interface ExistingMember {
  role: string;
  is_active: boolean;
}

export type MembershipAction =
  | "create"
  | "reactivate"
  | "change_role"
  | "unchanged";

export interface InvitePlan {
  action: MembershipAction;
  /** Value for tenant_role_assignments.previous_role. The column is NOT NULL
   * (enum), so a first grant repeats the new role, as the app already does. */
  previousRole: string;
  newRole: InviteRole;
}

export function planMembership(
  existing: ExistingMember | null,
  newRole: InviteRole,
): InvitePlan {
  if (existing === null) {
    return { action: "create", previousRole: newRole, newRole };
  }
  const previousRole = existing.role;
  if (!existing.is_active) {
    return { action: "reactivate", previousRole, newRole };
  }
  if (existing.role !== newRole) {
    return { action: "change_role", previousRole, newRole };
  }
  return { action: "unchanged", previousRole, newRole };
}

export interface DivisionRow {
  id: string;
  tenant_id: string;
  is_active: boolean;
}

/**
 * A division may only be used when it exists, belongs to the resolved tenant
 * and is still offered. Rows come from a service-client query, so the check is
 * made here rather than trusted to the request.
 */
export function divisionUsable(
  row: DivisionRow | null | undefined,
  tenantId: string,
): boolean {
  return !!row && row.is_active === true &&
    row.tenant_id.toLowerCase() === tenantId.toLowerCase();
}

/**
 * Every requested division must exist, be active and belong to the resolved
 * tenant. A missing row (unknown id) fails the whole set.
 */
export function divisionsUsable(
  rows: DivisionRow[] | null | undefined,
  ids: string[],
  tenantId: string,
): boolean {
  const byId = new Map<string, DivisionRow>();
  for (const r of rows ?? []) byId.set(r.id.toLowerCase(), r);
  return ids.every((id) => divisionUsable(byId.get(id.toLowerCase()), tenantId));
}

/** Invites only add: the wanted ids the member does not already have. */
export function divisionsToAdd(existing: string[], wanted: string[]): string[] {
  const have = new Set(existing.map((e) => e.toLowerCase()));
  return wanted.filter((w) => !have.has(w.toLowerCase()));
}

export function rateLimitSince(now: number): string {
  return new Date(now - RATE_LIMIT_WINDOW_MS).toISOString();
}

export function isRateLimited(recentInvites: number): boolean {
  return recentInvites >= RATE_LIMIT_MAX;
}

/** Only the domain of an address is safe to log. */
export function emailDomain(email: string): string {
  const at = email.lastIndexOf("@");
  return at < 0 ? "unknown" : email.slice(at + 1);
}
