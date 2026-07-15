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

  const caller = createClient(supabaseUrl, publicKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const token = authorization.slice("Bearer ".length);
  const { data: userData, error: userError } = await caller.auth.getUser(token);
  if (userError || !userData.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const body = await request.json();
  const { data: invitation, error: invitationError } = await caller.rpc(
    "invite_family_member",
    {
      p_family_id: body.family_id,
      p_kingdom_id: body.kingdom_id,
      p_email: body.email,
      p_role: body.role ?? "adventurer",
      p_membership_scope: body.membership_scope ?? "kingdom",
      p_domain_id: body.domain_id ?? null,
      p_expires_in_days: body.expires_in_days ?? 7,
    },
  );
  if (invitationError) {
    return json({ error: invitationError.message }, 403);
  }

  const publicUrl = new URL(
    Deno.env.get("APP_PUBLIC_URL") ??
      "https://homequest33310.github.io/homequest/",
  );
  publicUrl.searchParams.set("invite", invitation.token);

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: emailError } = await admin.auth.admin.inviteUserByEmail(
    invitation.email,
    {
      redirectTo: publicUrl.toString(),
      data: { invitation_token: invitation.token },
    },
  );

  return json({
    invitation,
    email_sent: emailError == null,
    email_error: emailError?.message ?? null,
    invite_url: publicUrl.toString(),
  });
});
