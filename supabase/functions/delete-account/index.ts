// Edge Function: delete-account
// Permanently deletes the CALLER's own account. The caller proves identity with
// their normal Supabase session JWT (sent in the Authorization header). We
// resolve that JWT to a user id, then use the service-role key to delete that
// auth.users row. Every table references profiles(id) -> auth.users(id) with
// ON DELETE CASCADE, so all of the user's data is removed in one step.
//
// This satisfies Apple App Store Guideline 5.1.1(v): in-app account deletion.
//
// A user can ONLY ever delete themselves: we ignore any id in the request body
// and use the id derived from the verified JWT.
//
// Deploy: supabase functions deploy delete-account
//   (needs SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in the function's secrets;
//    both are provided automatically by Supabase for deployed functions.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  // CORS preflight (the Flutter web build issues one; harmless on mobile).
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: corsHeaders },
    );
  }

  // The caller's session token. Without it we cannot know who to delete.
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    return Response.json(
      { error: "Missing Authorization bearer token" },
      { status: 401, headers: corsHeaders },
    );
  }

  // Verify the token and resolve the user with an anon-key client scoped to it.
  const asUser = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: userData, error: userErr } = await asUser.auth.getUser();
  if (userErr || !userData?.user) {
    return Response.json(
      { error: "Invalid or expired session" },
      { status: 401, headers: corsHeaders },
    );
  }
  const userId = userData.user.id;

  // Delete the auth user with the service role. Data cascades via FKs.
  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    return Response.json(
      { error: delErr.message },
      { status: 500, headers: corsHeaders },
    );
  }

  return Response.json({ ok: true }, { headers: corsHeaders });
});
