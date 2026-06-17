// Edge Function: sweep-presence
// Deletes expired live_presence rows so the map self-cleans even if a client
// crashes without ending its session. Invoked by pg_cron every ~2 minutes.
//
// Deploy: supabase functions deploy sweep-presence

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async () => {
  const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
  const { error } = await supabase
    .from("live_presence")
    .delete()
    .lt("expires_at", new Date().toISOString());
  if (error) return Response.json({ error: error.message }, { status: 500 });
  return Response.json({ ok: true });
});
