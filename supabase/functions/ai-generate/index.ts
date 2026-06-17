// Edge Function: ai-generate
// Generates follow-up message drafts and daily encouragement using Claude.
// Runs with the service-role key (set as a function secret). The AI provider
// key (ANTHROPIC_API_KEY) is also a secret — never call the AI API from the app.
//
// Deploy: supabase functions deploy ai-generate
// Secrets: supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MODEL = "claude-opus-4-8";

async function claude(system: string, user: string): Promise<string> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "x-api-key": ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 256,
      system,
      messages: [{ role: "user", content: user }],
    }),
  });
  const data = await res.json();
  return data?.content?.[0]?.text?.trim() ?? "";
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const mode = body.mode ?? "followup";

    if (mode === "followup") {
      const supabase = createClient(SUPABASE_URL, SERVICE_KEY);
      const { data: contact } = await supabase
        .from("contacts")
        .select("first_name, status, met_location")
        .eq("id", body.contact_id)
        .single();

      const system =
        "You write warm, brief, non-pushy follow-up messages for a Christian evangelist. Return 1-3 sentences, no preamble.";
      const user =
        `Write a day-${body.day_offset ?? 1} follow-up to ${contact?.first_name ?? "a new friend"}` +
        ` (spiritual status: ${contact?.status ?? "new_contact"}` +
        (contact?.met_location ? `, met at ${contact.met_location}` : "") + ").";
      const message = await claude(system, user);
      return Response.json({ message });
    }

    // daily encouragement
    const theme = body.theme ?? "boldness";
    const system =
      "You write short, Scripture-anchored encouragement for Christian evangelists. One sentence, never preachy.";
    const message = await claude(system, `Theme: ${theme}. Encourage me to share the Gospel today.`);
    return Response.json({ message });
  } catch (e) {
    return Response.json({ error: String(e) }, { status: 500 });
  }
});
