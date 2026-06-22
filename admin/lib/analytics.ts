import "server-only";
import { supabaseAdmin } from "./supabaseAdmin";

// Server-side analytics layer. Every function calls one of the admin_* RPCs
// deployed by supabase/migrate_admin_analytics.sql. If that migration hasn't
// been applied yet, the RPCs 404 — we surface that as `migrationMissing` so the
// pages can show a friendly "apply the migration" banner instead of crashing.

export class MigrationMissingError extends Error {
  constructor(fn: string) {
    super(`RPC ${fn} not found — apply supabase/migrate_admin_analytics.sql`);
    this.name = "MigrationMissingError";
  }
}

async function rpc<T>(fn: string, params?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabaseAdmin().rpc(fn, params ?? {});
  if (error) {
    // PostgREST returns 404 / PGRST202 when the function doesn't exist.
    if (
      error.code === "PGRST202" ||
      /could not find the function|does not exist/i.test(error.message)
    ) {
      throw new MigrationMissingError(fn);
    }
    throw new Error(`${fn}: ${error.message}`);
  }
  return data as T;
}

// Wrap a page's data fetch so a missing migration becomes a soft flag.
export async function safe<T>(
  load: () => Promise<T>,
): Promise<{ data: T | null; migrationMissing: boolean; error: string | null }> {
  try {
    return { data: await load(), migrationMissing: false, error: null };
  } catch (e) {
    if (e instanceof MigrationMissingError) {
      return { data: null, migrationMissing: true, error: null };
    }
    return { data: null, migrationMissing: false, error: (e as Error).message };
  }
}

// ---- Types (mirror the RPC return shapes) ----------------------------------

export type Kpi = {
  total_users: number;
  users_7d: number;
  users_prev_7d: number;
  total_salvations: number;
  total_conversations: number;
  total_prayers: number;
  total_posts: number;
  posts_7d: number;
  posts_prev_7d: number;
  total_churches: number;
  verified_churches: number;
  live_now: number;
};

export type DailySignup = { day: string; signups: number; cumulative: number };
export type NameValue = { name: string; value: number };
export type DailyActivity = {
  day: string;
  conversation: number;
  salvation: number;
  prayer: number;
  followup: number;
  church_connection: number;
  total: number;
};
export type DailyPosts = {
  day: string;
  testimony: number;
  outreach: number;
  prayer: number;
  salvation: number;
  update_: number;
  total: number;
};
export type FunnelStep = { stage: string; users: number; step_order: number };
export type ContactFunnelStep = { status: string; contacts: number; step_order: number };
export type Leader = {
  id: string;
  full_name: string;
  username: string | null;
  city: string | null;
  avatar_url: string | null;
  metric: number;
};
export type StreakBucket = { bucket: string; users: number; bucket_order: number };
export type Achievement = { key: string; name: string; icon: string; unlocks: number; sort_order: number };
export type Activation = { signups: number; activated: number; rate: number };
export type CohortRow = {
  cohort_week: string;
  cohort_size: number;
  week_offset: number;
  active_users: number;
  retention: number;
};
export type CommunityStats = {
  total_posts: number;
  posts_7d: number;
  total_reactions: number;
  total_comments: number;
  avg_reactions: number;
  avg_comments: number;
};
export type TopPost = {
  id: string;
  body: string;
  type: string;
  author: string;
  created_at: string;
  reactions: number;
  comments: number;
  engagement: number;
};
export type GeoActivity = { lat: number; lng: number; type: string; occurred_at: string };
export type GeoChurch = {
  id: string;
  name: string;
  city: string | null;
  is_verified: boolean;
  claim_status: string | null;
  lat: number;
  lng: number;
};
export type GeoLive = { lat: number; lng: number };
export type GeoPost = { id: string; type: string; lat: number; lng: number; created_at: string };
export type CityRollup = {
  city: string;
  users: number;
  salvations: number;
  conversations: number;
  churches: number;
  active_now: number;
};

// ---- Overview ---------------------------------------------------------------

export const getKpiOverview = () =>
  rpc<Kpi[]>("admin_kpi_overview").then((r) => r[0]);

export const getLiveCount = () => rpc<number>("admin_live_count");

// ---- Growth -----------------------------------------------------------------

export const getDailySignups = (days = 90) =>
  rpc<DailySignup[]>("admin_daily_signups", { p_days: days });

export const getSignupsBySource = (days = 30) =>
  rpc<{ source: string; signups: number }[]>("admin_signups_by_source", { p_days: days }).then(
    (r) => r.map((x) => ({ name: x.source, value: x.signups })),
  );

export const getSignupsByCity = (days = 30, limit = 12) =>
  rpc<{ city: string; signups: number }[]>("admin_signups_by_city", {
    p_days: days,
    p_limit: limit,
  }).then((r) => r.map((x) => ({ name: x.city, value: x.signups })));

export const getPlatformSplit = () =>
  rpc<{ platform: string; users: number }[]>("admin_platform_split").then((r) =>
    r.map((x) => ({ name: x.platform, value: x.users })),
  );

export const getActivationRate = (days = 30, windowDays = 7) =>
  rpc<Activation[]>("admin_activation_rate", {
    p_days: days,
    p_window_days: windowDays,
  }).then((r) => r[0]);

export const getCohortRetention = (weeks = 8) =>
  rpc<CohortRow[]>("admin_cohort_retention", { p_weeks: weeks });

export const getProductFunnel = () => rpc<FunnelStep[]>("admin_product_funnel");

// ---- Kingdom impact ---------------------------------------------------------

export const getDailyActivity = (days = 30) =>
  rpc<DailyActivity[]>("admin_daily_activity", { p_days: days });

export const getActivityMix = () =>
  rpc<{ type: string; n: number }[]>("admin_activity_mix").then((r) =>
    r.map((x) => ({ name: x.type, value: x.n })),
  );

export const getLeaderboard = (metric = "salvations", limit = 10) =>
  rpc<Leader[]>("admin_leaderboard", { p_metric: metric, p_limit: limit });

export const getStreakDistribution = () =>
  rpc<StreakBucket[]>("admin_streak_distribution");

export const getAchievementDistribution = () =>
  rpc<Achievement[]>("admin_achievement_distribution");

export const getContactFunnel = () =>
  rpc<ContactFunnelStep[]>("admin_contact_funnel");

// ---- Community --------------------------------------------------------------

export const getCommunityStats = () =>
  rpc<CommunityStats[]>("admin_community_stats").then((r) => r[0]);

export const getDailyPosts = (days = 30) =>
  rpc<DailyPosts[]>("admin_daily_posts", { p_days: days });

export const getPostTypeMix = () =>
  rpc<{ type: string; n: number }[]>("admin_post_type_mix").then((r) =>
    r.map((x) => ({ name: x.type, value: x.n })),
  );

export const getReactionMix = () =>
  rpc<{ reaction: string; n: number }[]>("admin_reaction_mix").then((r) =>
    r.map((x) => ({ name: x.reaction, value: x.n })),
  );

export const getTopPosts = (limit = 10) =>
  rpc<TopPost[]>("admin_top_posts", { p_limit: limit });

// ---- Map --------------------------------------------------------------------

export const getGeoActivity = (days = 30, limit = 2000) =>
  rpc<GeoActivity[]>("admin_geo_activity", { p_days: days, p_limit: limit });

export const getGeoChurches = () => rpc<GeoChurch[]>("admin_geo_churches");

export const getGeoLive = () => rpc<GeoLive[]>("admin_geo_live");

export const getGeoPosts = (days = 30, limit = 500) =>
  rpc<GeoPost[]>("admin_geo_posts", { p_days: days, p_limit: limit });

export const getCityRollup = (limit = 25) =>
  rpc<CityRollup[]>("admin_city_rollup", { p_limit: limit });

// ---- Church fruitfulness (membership) --------------------------------------

export type ChurchFruit = {
  church_id: string;
  name: string;
  city: string | null;
  is_verified: boolean;
  members: number;
  active_members: number;
  salvations: number;
  conversations: number;
  prayers: number;
  followups: number;
  fruitfulness: number;
};

export type ChurchMember = {
  membership_id: string;
  member_id: string;
  full_name: string | null;
  username: string | null;
  city: string | null;
  status: string;
  requested_at: string;
  confirmed_at: string | null;
  total_salvations: number;
  total_conversations: number;
  current_streak: number;
};

export type MembershipStats = {
  churches_with_members: number;
  confirmed_members: number;
  pending_members: number;
  members_evangelizing: number;
};

export const getChurchFruitfulness = (days: number | null = null, limit = 100) =>
  rpc<ChurchFruit[]>("admin_church_fruitfulness", { p_days: days, p_limit: limit });

export const getChurchMembers = (churchId: string) =>
  rpc<ChurchMember[]>("admin_church_members", { p_church_id: churchId });

export const getMembershipStats = () =>
  rpc<MembershipStats[]>("admin_membership_stats").then((r) => r[0]);
