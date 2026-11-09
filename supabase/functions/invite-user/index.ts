// Supabase Edge Function: invite-user
//
// An ADMIN of a tenant invites someone by email. Creating a sign-in account
// needs the service role key, which lives only here (SUPABASE_SERVICE_ROLE_KEY
// is injected by Supabase) and never ships in the app.
//
// Deploy (JWT verification ON, the default; do NOT pass --no-verify-jwt):
//   supabase functions deploy invite-user
//
// Request JSON body (caller's JWT in the Authorization header):
//   { email, displayName,
//     role: 'apprentice'|'technician'|'supervisor'|'dispatcher'|'admin',
//     phone?, redirectTo?, tenantId?,
//     divisionIds?: uuid[] (max 10), divisionId?: uuid (older single form) }
// Response: { ok: true, userId, invited: boolean, role }  or  { error }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, json } from "./cors.ts";
import {
  divisionsToAdd,
  divisionsUsable,
  emailDomain,
  INVITE_REASON,
  isRateLimited,
  planMembership,
  rateLimitSince,
  resolveTenant,
} from "./plan.ts";
import type { Membership } from "./plan.ts";
import { validateInvite } from "./validate.ts";

// deno-lint-ignore no-explicit-any
type Db = any;

async function findUserIdByEmail(
  admin: Db,
  email: string,
): Promise<string | null> {
  // Cheap path: the profile row, matched case-insensitively and exactly.
  const { data: prof } = await admin
    .from("user_profiles")
    .select("user_id")
    .ilike("email", email.replace(/[\\%_]/g, "\\$&"))
    .limit(1);
  if (prof && prof.length > 0 && prof[0].user_id) return prof[0].user_id;

  // Fallback: page through auth users (no server-side email filter exists).
  const perPage = 1000;
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) return null;
    const hit = data.users.find((u: { email?: string }) =>
      (u.email ?? "").toLowerCase() === email
    );
    if (hit) return hit.id;
    if (data.users.length < perPage) break;
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Sign in to invite people." }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) {
    console.error("invite-user: missing Supabase environment");
    return json({ error: "Server is not configured." }, 500);
  }

  // (a) Who is calling? Resolved from the caller's own JWT.
  const callerClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) {
    return json({ error: "Sign in to invite people." }, 401);
  }
  const callerId = userData.user.id;

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Request body must be valid JSON." }, 400);
  }

  const admin: Db = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // (b) Authorization comes from the database, never from the request.
  // Checked before validation so non-admins learn nothing about the rules.
  const { data: memberships, error: memErr } = await admin
    .from("tenant_members")
    .select("tenant_id, role, is_active")
    .eq("user_id", callerId);
  if (memErr) {
    console.error("invite-user: membership lookup failed", memErr.code);
    return json({ error: "Could not check your permissions." }, 500);
  }
  const callerMemberships = (memberships ?? []) as Membership[];
  const isAdminSomewhere = callerMemberships.some((m) =>
    m.is_active === true && m.role === "admin"
  );
  if (!isAdminSomewhere) {
    return json({ error: "Only admins can invite people." }, 403);
  }

  // (c) Validate input.
  const parsed = validateInvite(body);
  if (!parsed.ok) return json({ error: parsed.message }, 400);
  const input = parsed.value;

  const tenant = resolveTenant(callerMemberships, input.tenantId);
  if (!tenant.ok) return json({ error: tenant.message }, tenant.status);
  const tenantId = tenant.tenantId;

  // Every division, if any, must be one of THIS company's active divisions.
  // Checked with the service client; the request is not trusted for it.
  if (input.divisionIds.length > 0) {
    const { data: divRows, error: divErr } = await admin
      .from("divisions")
      .select("id, tenant_id, is_active")
      .in("id", input.divisionIds);
    if (divErr) {
      console.error("invite-user: division lookup failed", divErr.code);
      return json({ error: "Could not check the divisions." }, 500);
    }
    if (!divisionsUsable(divRows, input.divisionIds, tenantId)) {
      return json({ error: "That division is not available." }, 400);
    }
  }

  // Rate limit: invites recorded by this caller in the last hour.
  const { count, error: countErr } = await admin
    .from("tenant_role_assignments")
    .select("id", { count: "exact", head: true })
    .eq("assigned_by_user_id", callerId)
    .eq("reason", INVITE_REASON)
    .gte("created_at", rateLimitSince(Date.now()));
  if (countErr) {
    console.error("invite-user: rate check failed", countErr.code);
    return json({ error: "Could not process the invitation." }, 500);
  }
  if (isRateLimited(count ?? 0)) {
    return json({ error: "Too many invitations. Try again in an hour." }, 429);
  }

  console.log(
    `invite-user: tenant=${tenantId} role=${input.role} domain=${
      emailDomain(input.email)
    }`,
  );

  // (d) Create the account (sends the invite email), or reuse the existing one.
  let userId: string | null = null;
  let invited = true;
  const { data: inv, error: invErr } = await admin.auth.admin
    .inviteUserByEmail(input.email, {
      redirectTo: input.redirectTo ?? undefined,
      data: { display_name: input.displayName },
    });
  if (!invErr && inv?.user?.id) {
    userId = inv.user.id;
  } else {
    const msg = (invErr?.message ?? "").toLowerCase();
    const exists = invErr?.status === 422 || msg.includes("already") ||
      msg.includes("registered");
    if (!exists) {
      console.error("invite-user: invite failed", invErr?.status, invErr?.code);
      return json(
        { error: "The invitation could not be sent. Try again later." },
        502,
      );
    }
    invited = false;
    userId = await findUserIdByEmail(admin, input.email);
    if (!userId) {
      console.error("invite-user: existing user not found");
      return json({ error: "Could not find that account." }, 502);
    }
  }

  // (e) Idempotent writes.
  const { data: existingRows, error: exErr } = await admin
    .from("tenant_members")
    .select("role, is_active")
    .eq("tenant_id", tenantId)
    .eq("user_id", userId)
    .limit(1);
  if (exErr) {
    console.error("invite-user: member read failed", exErr.code);
    return json({ error: "Could not process the invitation." }, 500);
  }
  const existing = existingRows && existingRows.length > 0
    ? existingRows[0]
    : null;
  const plan = planMembership(existing, input.role);

  // Profile: a brand-new account or an existing member of THIS tenant is
  // updated; a person who belongs elsewhere keeps the profile they have.
  const { data: profRows } = await admin
    .from("user_profiles")
    .select("user_id")
    .eq("user_id", userId)
    .limit(1);
  const hasProfile = !!profRows && profRows.length > 0;
  if (!hasProfile || existing !== null || invited) {
    const { error: pErr } = await admin.from("user_profiles").upsert({
      user_id: userId,
      display_name: input.displayName,
      email: input.email,
      phone: input.phone,
      is_active: true,
    }, { onConflict: "user_id" });
    if (pErr) {
      console.error("invite-user: profile upsert failed", pErr.code);
      return json({ error: "Could not save the profile." }, 500);
    }
  }

  // Audit first, membership second: a grant must never exist without a record.
  const { error: aErr } = await admin.from("tenant_role_assignments").insert({
    tenant_id: tenantId,
    user_id: userId,
    previous_role: plan.previousRole,
    new_role: plan.newRole,
    assigned_by_user_id: callerId,
    reason: INVITE_REASON,
  });
  if (aErr) {
    console.error("invite-user: audit insert failed", aErr.code);
    return json({ error: "Could not record the invitation." }, 500);
  }

  const { error: mErr } = await admin.from("tenant_members").upsert({
    tenant_id: tenantId,
    user_id: userId,
    role: plan.newRole,
    is_active: true,
    updated_at: new Date().toISOString(),
    // Deprecated single column, kept for older app builds. Only sent when
    // chosen, so re-inviting someone never clears their divisions.
    ...(input.divisionIds.length > 0
      ? { division_id: input.divisionIds[0] }
      : {}),
  }, { onConflict: "tenant_id,user_id" });
  if (mErr) {
    console.error("invite-user: membership upsert failed", mErr.code);
    return json({ error: "Could not add the member." }, 500);
  }

  // Divisions: an invite only ADDS (it never removes a division the member
  // already has). member_divisions is the source of truth.
  if (input.divisionIds.length > 0) {
    const { data: haveRows, error: hErr } = await admin
      .from("member_divisions")
      .select("division_id")
      .eq("tenant_id", tenantId)
      .eq("user_id", userId);
    if (hErr) {
      console.error("invite-user: member divisions read failed", hErr.code);
      return json({ error: "Could not save the divisions." }, 500);
    }
    const toAdd = divisionsToAdd(
      (haveRows ?? []).map((r: { division_id: string }) => r.division_id),
      input.divisionIds,
    );
    if (toAdd.length > 0) {
      const { error: dErr } = await admin.from("member_divisions").insert(
        toAdd.map((division_id) => ({
          tenant_id: tenantId,
          user_id: userId,
          division_id,
        })),
      );
      if (dErr) {
        console.error("invite-user: member divisions insert failed", dErr.code);
        return json({ error: "Could not save the divisions." }, 500);
      }
    }
  }

  // (f)
  return json({ ok: true, userId, invited, role: input.role });
});
