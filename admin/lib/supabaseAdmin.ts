import "server-only";
import { createClient, SupabaseClient } from "@supabase/supabase-js";

// Service-role Supabase client. Bypasses RLS — full access to every table.
// The `server-only` import above makes the build FAIL if this file is ever
// pulled into a client component, so the service-role key cannot leak to the
// browser. Only import this from server components, route handlers, or
// server actions.

let cached: SupabaseClient | null = null;

export function supabaseAdmin(): SupabaseClient {
  if (cached) return cached;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error(
      "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY (see admin/.env.example).",
    );
  }
  cached = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return cached;
}
