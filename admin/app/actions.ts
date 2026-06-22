"use server";

import { revalidatePath } from "next/cache";
import { supabaseAdmin } from "@/lib/supabaseAdmin";
import { requireAdmin } from "@/lib/requireAdmin";

// Server actions invoked from dashboard buttons. Each re-checks the admin
// session, then performs a single privileged write with the service role.

export async function deletePost(formData: FormData): Promise<void> {
  await requireAdmin();
  const id = String(formData.get("id") ?? "");
  if (!id) throw new Error("Missing post id");
  const { error } = await supabaseAdmin().from("posts").delete().eq("id", id);
  if (error) throw new Error(`deletePost: ${error.message}`);
  revalidatePath("/community");
  revalidatePath("/");
}

// Approve a church after the vetting meeting: mark it verified AND record the
// claim as approved. Or revoke (verified=false) without touching claim status.
export async function setChurchVerified(formData: FormData): Promise<void> {
  await requireAdmin();
  const id = String(formData.get("id") ?? "");
  const verified = String(formData.get("verified") ?? "") === "true";
  if (!id) throw new Error("Missing church id");
  const patch: Record<string, unknown> = { is_verified: verified };
  if (verified) patch.claim_status = "approved";
  const { error } = await supabaseAdmin()
    .from("churches")
    .update(patch)
    .eq("id", id);
  if (error) throw new Error(`setChurchVerified: ${error.message}`);
  revalidatePath("/churches");
  revalidatePath("/");
}

// Reject a claim (e.g. couldn't confirm the pastor). Keeps the listing but
// marks it rejected and ensures it is not shown as verified.
export async function rejectChurchClaim(formData: FormData): Promise<void> {
  await requireAdmin();
  const id = String(formData.get("id") ?? "");
  if (!id) throw new Error("Missing church id");
  const { error } = await supabaseAdmin()
    .from("churches")
    .update({ claim_status: "rejected", is_verified: false })
    .eq("id", id);
  if (error) throw new Error(`rejectChurchClaim: ${error.message}`);
  revalidatePath("/churches");
  revalidatePath("/");
}

// --- Church membership moderation (admin can confirm/remove on a member's
// behalf from the dashboard). These write church_members directly with the
// service role, mirroring the in-app confirm_member / remove_member RPCs. ---

export async function adminConfirmMember(formData: FormData): Promise<void> {
  await requireAdmin();
  const membershipId = String(formData.get("membership_id") ?? "");
  if (!membershipId) throw new Error("Missing membership id");
  const sb = supabaseAdmin();
  const { data: row, error: readErr } = await sb
    .from("church_members")
    .select("church_id,member_id")
    .eq("id", membershipId)
    .single();
  if (readErr) throw new Error(`adminConfirmMember(read): ${readErr.message}`);
  const { error } = await sb
    .from("church_members")
    .update({ status: "confirmed", confirmed_at: new Date().toISOString() })
    .eq("id", membershipId);
  if (error) throw new Error(`adminConfirmMember: ${error.message}`);
  // Mirror onto profiles.church_id (same as the confirm_member RPC).
  await sb.from("profiles").update({ church_id: row.church_id }).eq("id", row.member_id);
  revalidatePath("/churches");
}

export async function adminRemoveMember(formData: FormData): Promise<void> {
  await requireAdmin();
  const membershipId = String(formData.get("membership_id") ?? "");
  if (!membershipId) throw new Error("Missing membership id");
  const sb = supabaseAdmin();
  const { data: row } = await sb
    .from("church_members")
    .select("church_id,member_id")
    .eq("id", membershipId)
    .single();
  const { error } = await sb
    .from("church_members")
    .update({ status: "removed" })
    .eq("id", membershipId);
  if (error) throw new Error(`adminRemoveMember: ${error.message}`);
  if (row) {
    await sb
      .from("profiles")
      .update({ church_id: null })
      .eq("id", row.member_id)
      .eq("church_id", row.church_id);
  }
  revalidatePath("/churches");
}
