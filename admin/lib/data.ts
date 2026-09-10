import "server-only";
import { supabaseAdmin } from "./supabaseAdmin";
import { truncate } from "./format";

// Read/aggregate helpers for the dashboard. All run server-side with the
// service-role client, so they see across every user (RLS bypassed).
//
// NOTE ON EMAILS: identity (name/email/login) lives in CLERK, not Supabase.
// `profiles` holds the public profile + cached stats. Email is intentionally
// not here. To show emails, call the Clerk Backend API with CLERK_SECRET_KEY
// (left as a future enhancement — see admin/README.md).

export type ProfileRow = {
  id: string;
  full_name: string;
  username: string | null;
  city: string | null;
  church: string | null;
  ministry: string | null;
  current_streak: number;
  longest_streak: number;
  total_conversations: number;
  total_salvations: number;
  total_followups: number;
  total_church_connections: number;
  created_at: string;
};

export type PostRow = {
  id: string;
  type: string;
  body: string;
  photo_url: string | null;
  city: string | null;
  created_at: string;
  author_id: string;
  profiles: { full_name: string | null; church: string | null } | null;
};

export type ChurchRow = {
  id: string;
  name: string;
  city: string | null;
  address: string | null;
  service_times: string | null;
  website: string | null;
  is_verified: boolean;
  claimed_by: string | null;
  created_at: string;
  // Claim / vetting fields (added by migrate_church_registration.sql).
  claim_status: string | null;
  claimant_name: string | null;
  claimant_role: string | null;
  claimant_phone: string | null;
  claimant_email: string | null;
  claim_notes: string | null;
  // Lead pastor contact (added by migrate_church_pastor.sql). The team calls
  // or emails the pastor to book the verification visit.
  pastor_name: string | null;
  pastor_phone: string | null;
  pastor_email: string | null;
  best_time_to_meet: string | null;
};

export type Overview = {
  totalUsers: number;
  totalSalvations: number;
  totalConversations: number;
  totalPosts: number;
  totalChurches: number;
  verifiedChurches: number;
  newUsers7d: number;
  newPosts7d: number;
  /** Anonymous guest sessions (fresh installs that never made an account). */
  guestSessions: number;
};

function sevenDaysAgoIso(): string {
  // Stable enough for a "last 7 days" rollup; computed at request time.
  return new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
}

async function count(
  table: string,
  build?: (q: any) => any,
): Promise<number> {
  let q = supabaseAdmin().from(table).select("*", { count: "exact", head: true });
  if (build) q = build(q);
  const { count: c, error } = await q;
  if (error) throw new Error(`count(${table}): ${error.message}`);
  return c ?? 0;
}

// Guests are anonymous sessions created on every fresh install; they are not
// users. `profiles.is_guest` comes from migrate_guest_flag.sql — until that has
// run the column is missing, so fall back to the unfiltered number rather than
// breaking the page.
async function countRealUsers(build?: (q: any) => any): Promise<number> {
  try {
    return await count("profiles", (q) => {
      const base = q.eq("is_guest", false);
      return build ? build(base) : base;
    });
  } catch (e) {
    if (String(e).includes("is_guest")) return count("profiles", build);
    throw e;
  }
}

async function countGuests(): Promise<number> {
  try {
    return await count("profiles", (q) => q.eq("is_guest", true));
  } catch (e) {
    if (String(e).includes("is_guest")) return 0;
    throw e;
  }
}

async function sumColumn(table: string, column: string): Promise<number> {
  // Small tables (profiles) — summing client-side is fine and avoids an RPC.
  const { data, error } = await supabaseAdmin().from(table).select(column);
  if (error) throw new Error(`sum(${table}.${column}): ${error.message}`);
  return (data ?? []).reduce(
    (acc: number, row: any) => acc + (Number(row[column]) || 0),
    0,
  );
}

export async function getOverview(): Promise<Overview> {
  const since = sevenDaysAgoIso();
  const [
    totalUsers,
    totalPosts,
    totalChurches,
    verifiedChurches,
    newUsers7d,
    newPosts7d,
    totalSalvations,
    totalConversations,
    guestSessions,
  ] = await Promise.all([
    countRealUsers(),
    count("posts"),
    count("churches"),
    count("churches", (q) => q.eq("is_verified", true)),
    countRealUsers((q) => q.gte("created_at", since)),
    count("posts", (q) => q.gte("created_at", since)),
    sumColumn("profiles", "total_salvations"),
    sumColumn("profiles", "total_conversations"),
    countGuests(),
  ]);

  return {
    totalUsers,
    totalSalvations,
    totalConversations,
    totalPosts,
    totalChurches,
    verifiedChurches,
    newUsers7d,
    newPosts7d,
    guestSessions,
  };
}

export async function getUsers(limit = 200): Promise<ProfileRow[]> {
  const columns =
    "id,full_name,username,city,church,ministry,current_streak,longest_streak," +
    "total_conversations,total_salvations,total_followups,total_church_connections,created_at";
  const query = (guestFilter: boolean) => {
    let q = supabaseAdmin().from("profiles").select(columns);
    if (guestFilter) q = q.eq("is_guest", false);
    return q.order("created_at", { ascending: false }).limit(limit);
  };
  let { data, error } = await query(true);
  if (error && error.message.includes("is_guest")) ({ data, error } = await query(false));
  if (error) throw new Error(`getUsers: ${error.message}`);
  return (data ?? []) as unknown as ProfileRow[];
}

export async function getPosts(limit = 200): Promise<PostRow[]> {
  const { data, error } = await supabaseAdmin()
    .from("posts")
    .select(
      "id,type,body,photo_url,city,created_at,author_id," +
        "profiles!posts_author_id_fkey(full_name,church)",
    )
    .order("created_at", { ascending: false })
    .limit(limit);
  if (error) throw new Error(`getPosts: ${error.message}`);
  return (data ?? []) as unknown as PostRow[];
}

export type PulseItem = {
  kind: "signup" | "post" | "church" | "salvation";
  label: string;
  detail: string | null;
  at: string;
};

// A merged "recent activity" feed for the Overview pulse column. Reads the
// newest rows from a few tables and interleaves them by time. Small limits keep
// it cheap.
export async function getRecentPulse(limit = 12): Promise<PulseItem[]> {
  const sb = supabaseAdmin();
  const [signups, posts, churches] = await Promise.all([
    sb
      .from("profiles")
      .select("full_name,city,created_at")
      .eq("is_guest", false)
      .order("created_at", { ascending: false })
      .limit(limit),
    sb
      .from("posts")
      .select("type,body,created_at,profiles!posts_author_id_fkey(full_name)")
      .order("created_at", { ascending: false })
      .limit(limit),
    sb
      .from("churches")
      .select("name,city,created_at")
      .order("created_at", { ascending: false })
      .limit(limit),
  ]);

  const items: PulseItem[] = [];
  for (const r of signups.data ?? []) {
    items.push({
      kind: "signup",
      label: `${(r as any).full_name || "Someone"} joined`,
      detail: (r as any).city || null,
      at: (r as any).created_at,
    });
  }
  for (const r of posts.data ?? []) {
    const author = (r as any).profiles?.full_name || "Someone";
    const isSalv = (r as any).type === "salvation";
    items.push({
      kind: isSalv ? "salvation" : "post",
      label: isSalv ? `${author} recorded a salvation` : `${author} posted a ${(r as any).type}`,
      detail: truncate((r as any).body, 60) || null,
      at: (r as any).created_at,
    });
  }
  for (const r of churches.data ?? []) {
    items.push({
      kind: "church",
      label: `${(r as any).name} registered`,
      detail: (r as any).city || null,
      at: (r as any).created_at,
    });
  }
  return items
    .filter((i) => i.at)
    .sort((a, b) => (a.at < b.at ? 1 : -1))
    .slice(0, limit);
}

const CHURCH_COLUMNS =
  "id,name,city,address,service_times,website,is_verified,claimed_by,created_at," +
  "claim_status,claimant_name,claimant_role,claimant_phone,claimant_email,claim_notes";
const PASTOR_COLUMNS = ",pastor_name,pastor_phone,pastor_email,best_time_to_meet";

export async function getChurches(limit = 200): Promise<ChurchRow[]> {
  const query = (columns: string) =>
    supabaseAdmin()
      .from("churches")
      .select(columns)
      // Pending claims first (so the vetting queue is at the top), then newest.
      .order("is_verified", { ascending: true })
      .order("created_at", { ascending: false })
      .limit(limit);
  let { data, error } = await query(CHURCH_COLUMNS + PASTOR_COLUMNS);
  // Until migrate_church_pastor.sql has run, the pastor columns do not exist;
  // fall back to the older shape rather than breaking the whole page.
  if (error && /pastor|best_time_to_meet/.test(error.message)) {
    ({ data, error } = await query(CHURCH_COLUMNS));
  }
  if (error) throw new Error(`getChurches: ${error.message}`);
  return (data ?? []) as unknown as ChurchRow[];
}
