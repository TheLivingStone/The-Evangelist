// Edge Function: send-push
// Fan-out to Firebase Cloud Messaging (HTTP v1). Runs with the service-role key.
// Input: { user_id | user_ids, title, body, data }
//
// Deploy: supabase functions deploy send-push
// Secrets: FCM_PROJECT_ID, FCM_SERVICE_ACCOUNT_JSON (a Google service account)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID")!;

// NOTE: Obtaining an OAuth token from the service account JSON is omitted for
// brevity; use google-auth-library or a JWT grant. The shape below is the
// FCM HTTP v1 send payload.
async function sendToToken(accessToken: string, token: string, title: string, body: string, data: Record<string, string>) {
  await fetch(`https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`, {
    method: "POST",
    headers: { authorization: `Bearer ${accessToken}`, "content-type": "application/json" },
    body: JSON.stringify({ message: { token, notification: { title, body }, data } }),
  });
}

Deno.serve(async (req) => {
  try {
    const { user_id, user_ids, title, body, data } = await req.json();
    const ids: string[] = user_ids ?? (user_id ? [user_id] : []);
    if (ids.length === 0) return Response.json({ error: "no recipients" }, { status: 400 });

    const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
    const { data: devices } = await supabase
      .from("devices").select("fcm_token").in("user_id", ids);

    // const accessToken = await getAccessToken(); // from FCM_SERVICE_ACCOUNT_JSON
    const accessToken = Deno.env.get("FCM_ACCESS_TOKEN") ?? "";
    for (const d of devices ?? []) {
      await sendToToken(accessToken, d.fcm_token, title, body, data ?? {});
    }
    return Response.json({ sent: devices?.length ?? 0 });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
