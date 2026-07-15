import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const isUuid = (value: unknown): value is string =>
  typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Authentication required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ??
    Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const secretKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SECRET_KEY");
  if (!supabaseUrl || !publicKey || !secretKey) {
    return json({ error: "Server configuration is incomplete" }, 500);
  }

  const token = authorization.slice("Bearer ".length);
  const caller = createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: callerData, error: callerError } = await caller.auth.getUser(token);
  if (callerError || !callerData.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const body = await request.json().catch(() => ({}));
  if (!isUuid(body.kingdom_id) || !isUuid(body.member_id)) {
    return json({ error: "Invalid request" }, 400);
  }

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: callerMemberships, error: callerMembershipError } = await admin
    .from("family_members")
    .select("id")
    .eq("user_id", callerData.user.id)
    .eq("is_active", true);
  if (callerMembershipError) {
    return json({ error: "Unable to verify guardian" }, 500);
  }

  const callerMemberIds = (callerMemberships ?? []).map((row) => row.id);
  if (callerMemberIds.length === 0) {
    return json({ error: "Only active guardians can request a reset" }, 403);
  }

  const { data: guardianMembership, error: guardianError } = await admin
    .from("kingdom_members")
    .select("id")
    .eq("kingdom_id", body.kingdom_id)
    .in("member_id", callerMemberIds)
    .eq("role", "guardian")
    .eq("is_active", true)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .maybeSingle();
  if (guardianError || !guardianMembership) {
    return json({ error: "Only this kingdom's guardians can request a reset" }, 403);
  }

  const { data: targetKingdomMembership, error: targetKingdomError } = await admin
    .from("kingdom_members")
    .select("id")
    .eq("kingdom_id", body.kingdom_id)
    .eq("member_id", body.member_id)
    .eq("is_active", true)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
    .maybeSingle();
  if (targetKingdomError || !targetKingdomMembership) {
    return json({ error: "The member is not active in this kingdom" }, 404);
  }

  const { data: targetMember, error: targetMemberError } = await admin
    .from("family_members")
    .select("user_id")
    .eq("id", body.member_id)
    .eq("is_active", true)
    .maybeSingle();
  if (targetMemberError || !targetMember) {
    return json({ error: "Member not found" }, 404);
  }

  const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString();
  const { count, error: rateLimitError } = await admin
    .from("password_reset_requests")
    .select("id", { count: "exact", head: true })
    .eq("target_user_id", targetMember.user_id)
    .gte("requested_at", tenMinutesAgo);
  if (rateLimitError) {
    return json({ error: "Unable to verify request limit" }, 500);
  }
  if ((count ?? 0) > 0) {
    return json({ error: "A reset email was already requested recently" }, 429);
  }

  const { data: targetAuth, error: targetAuthError } = await admin.auth.admin
    .getUserById(targetMember.user_id);
  const email = targetAuth.user?.email;
  if (targetAuthError || !email) {
    return json({ error: "This member has no email address" }, 400);
  }

  const redirectBase = new URL(
    Deno.env.get("APP_PUBLIC_URL") ??
      "https://homequest33310.github.io/homequest/",
  );
  redirectBase.searchParams.set("password-recovery", "1");

  const { error: resetError } = await admin.auth.resetPasswordForEmail(email, {
    redirectTo: redirectBase.toString(),
  });
  if (resetError) {
    return json({ error: "The recovery email could not be sent" }, 502);
  }

  const { error: auditError } = await admin.from("password_reset_requests").insert({
    kingdom_id: body.kingdom_id,
    requested_by: callerData.user.id,
    target_user_id: targetMember.user_id,
  });
  if (auditError) {
    console.error("Password reset audit failed", auditError.message);
  }

  return json({ requested: true });
});
