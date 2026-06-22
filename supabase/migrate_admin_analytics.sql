-- =============================================================================
-- The Evangelist — Admin Analytics rollups + signup attribution
-- Built 2026-06-20 for the upgraded admin dashboard (admin/).
--
-- Everything here is for the SERVICE ROLE only (the admin web server calls
-- these with the service-role key). They are NOT granted to `authenticated`,
-- so the Flutter app and regular users can't see aggregate/PII-ish data.
--
-- SAFE TO RE-RUN: all objects use create-or-replace / if-not-exists.
--
-- Apply via the Supabase SQL Editor (runs as `postgres`) on project
-- ryufvbhddsntcrvpkpet, or `supabase db execute`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Signup attribution: where did this user come from?
--    Lets the Growth page answer "this campaign drove N signups, M activated".
--    Written by the Flutter app at registration (anon/auth can update own row).
-- -----------------------------------------------------------------------------
alter table profiles add column if not exists signup_source text;   -- e.g. 'instagram_ad', 'organic', 'qr_flyer'
alter table profiles add column if not exists utm_campaign  text;
alter table profiles add column if not exists utm_medium    text;
alter table profiles add column if not exists utm_source    text;

create index if not exists idx_profiles_created on profiles (created_at);
create index if not exists idx_profiles_source  on profiles (signup_source);

-- =============================================================================
-- 1. GROWTH & ACQUISITION
-- =============================================================================

-- Daily new signups within a window (defaults: last 90 days, fills gaps w/ 0).
create or replace function admin_daily_signups(p_days int default 90)
returns table(day date, signups int, cumulative bigint)
language sql security definer set search_path = public stable as $$
  with days as (
    select generate_series(
      (current_date - (p_days - 1)),
      current_date,
      interval '1 day'
    )::date as day
  ),
  per_day as (
    select date_trunc('day', created_at)::date as day, count(*)::int as n
    from profiles
    where created_at >= (current_date - (p_days - 1))
    group by 1
  )
  select
    d.day,
    coalesce(p.n, 0) as signups,
    sum(coalesce(p.n, 0)) over (order by d.day) as cumulative
  from days d
  left join per_day p using (day)
  order by d.day;
$$;

-- New users broken down by acquisition source within a window.
create or replace function admin_signups_by_source(p_days int default 30)
returns table(source text, signups int)
language sql security definer set search_path = public stable as $$
  select
    coalesce(nullif(trim(signup_source), ''), 'unknown') as source,
    count(*)::int as signups
  from profiles
  where created_at >= (current_date - (p_days - 1))
  group by 1
  order by 2 desc;
$$;

-- New users by city (top N) within a window.
create or replace function admin_signups_by_city(p_days int default 30, p_limit int default 12)
returns table(city text, signups int)
language sql security definer set search_path = public stable as $$
  select
    coalesce(nullif(trim(city), ''), 'Unknown') as city,
    count(*)::int as signups
  from profiles
  where created_at >= (current_date - (p_days - 1))
  group by 1
  order by 2 desc
  limit p_limit;
$$;

-- Device platform split (iOS vs Android) — distinct users per platform.
create or replace function admin_platform_split()
returns table(platform text, users int)
language sql security definer set search_path = public stable as $$
  select
    coalesce(nullif(trim(platform), ''), 'unknown') as platform,
    count(distinct user_id)::int as users
  from devices
  group by 1
  order by 2 desc;
$$;

-- Activation: of users who signed up in the window, how many logged >=1
-- activity within `p_window_days` of signing up.
create or replace function admin_activation_rate(p_days int default 30, p_window_days int default 7)
returns table(signups int, activated int, rate numeric)
language sql security definer set search_path = public stable as $$
  with cohort as (
    select id, created_at
    from profiles
    where created_at >= (current_date - (p_days - 1))
  ),
  acted as (
    select c.id
    from cohort c
    where exists (
      select 1 from activity_logs a
      where a.user_id = c.id
        and a.occurred_at >= c.created_at
        and a.occurred_at <  c.created_at + (p_window_days || ' days')::interval
    )
  )
  select
    (select count(*) from cohort)::int as signups,
    (select count(*) from acted)::int  as activated,
    case when (select count(*) from cohort) = 0 then 0
         else round(100.0 * (select count(*) from acted) / (select count(*) from cohort), 1)
    end as rate;
$$;

-- Weekly cohort retention: for each signup-week, what % were still active in
-- each subsequent week (active = logged >=1 activity that week). Returns a
-- long/tidy grid the UI pivots into a heatmap. p_weeks = how many cohorts back.
create or replace function admin_cohort_retention(p_weeks int default 8)
returns table(
  cohort_week date,
  cohort_size int,
  week_offset int,
  active_users int,
  retention numeric
)
language sql security definer set search_path = public stable as $$
  with cohorts as (
    select
      id,
      date_trunc('week', created_at)::date as cohort_week
    from profiles
    where created_at >= date_trunc('week', current_date) - ((p_weeks - 1) || ' weeks')::interval
  ),
  sizes as (
    select cohort_week, count(*)::int as cohort_size
    from cohorts group by 1
  ),
  activity_weeks as (
    select distinct
      c.cohort_week,
      c.id,
      (extract(epoch from (date_trunc('week', a.occurred_at) - c.cohort_week)) / 604800)::int as week_offset
    from cohorts c
    join activity_logs a on a.user_id = c.id
    where a.occurred_at >= c.cohort_week
  ),
  active as (
    select cohort_week, week_offset, count(distinct id)::int as active_users
    from activity_weeks
    where week_offset >= 0
    group by 1, 2
  )
  select
    s.cohort_week,
    s.cohort_size,
    a.week_offset,
    a.active_users,
    round(100.0 * a.active_users / nullif(s.cohort_size, 0), 0) as retention
  from sizes s
  join active a using (cohort_week)
  order by s.cohort_week, a.week_offset;
$$;

-- The core product funnel: signed up -> any activity -> added a contact ->
-- recorded a salvation. Counts distinct users at each stage.
create or replace function admin_product_funnel()
returns table(stage text, users int, step_order int)
language sql security definer set search_path = public stable as $$
  select 'Signed up' as stage,
         (select count(*) from profiles)::int as users, 1 as step_order
  union all
  select 'Logged activity',
         (select count(distinct user_id) from activity_logs)::int, 2
  union all
  select 'Added a contact',
         (select count(distinct owner_id) from contacts)::int, 3
  union all
  select 'Recorded a salvation',
         (select count(distinct user_id) from activity_logs where type = 'salvation')::int, 4
  order by step_order;
$$;

-- =============================================================================
-- 2. KINGDOM IMPACT  (activity over time, leaderboards, achievements, funnel)
-- =============================================================================

-- Daily activity counts split by type (stacked-area source). Gap-filled.
create or replace function admin_daily_activity(p_days int default 30)
returns table(
  day date,
  conversation int,
  salvation int,
  prayer int,
  followup int,
  church_connection int,
  total int
)
language sql security definer set search_path = public stable as $$
  with days as (
    select generate_series(
      (current_date - (p_days - 1)), current_date, interval '1 day'
    )::date as day
  ),
  agg as (
    select date_trunc('day', occurred_at)::date as day, type, count(*)::int as n
    from activity_logs
    where occurred_at >= (current_date - (p_days - 1))
    group by 1, 2
  )
  select
    d.day,
    coalesce(sum(n) filter (where type = 'conversation'), 0)::int,
    coalesce(sum(n) filter (where type = 'salvation'), 0)::int,
    coalesce(sum(n) filter (where type = 'prayer'), 0)::int,
    coalesce(sum(n) filter (where type = 'followup'), 0)::int,
    coalesce(sum(n) filter (where type = 'church_connection'), 0)::int,
    coalesce(sum(n), 0)::int
  from days d
  left join agg a using (day)
  group by d.day
  order by d.day;
$$;

-- Lifetime activity mix (donut). All-time counts per type.
create or replace function admin_activity_mix()
returns table(type text, n int)
language sql security definer set search_path = public stable as $$
  select type::text, count(*)::int as n
  from activity_logs
  group by 1
  order by 2 desc;
$$;

-- Leaderboard: top evangelists by a chosen metric.
-- p_metric one of: 'salvations','conversations','followups','streak'.
create or replace function admin_leaderboard(p_metric text default 'salvations', p_limit int default 10)
returns table(
  id text,
  full_name text,
  username text,
  city text,
  avatar_url text,
  metric int
)
language sql security definer set search_path = public stable as $$
  select id, full_name, username, city, avatar_url,
    case p_metric
      when 'conversations' then total_conversations
      when 'followups'     then total_followups
      when 'streak'        then current_streak
      else total_salvations
    end as metric
  from profiles
  order by metric desc nulls last
  limit p_limit;
$$;

-- Streak distribution histogram (buckets of current_streak across users).
create or replace function admin_streak_distribution()
returns table(bucket text, users int, bucket_order int)
language sql security definer set search_path = public stable as $$
  with b as (
    select
      case
        when current_streak = 0 then '0'
        when current_streak between 1 and 2 then '1-2'
        when current_streak between 3 and 6 then '3-6'
        when current_streak between 7 and 13 then '7-13'
        when current_streak between 14 and 29 then '14-29'
        else '30+'
      end as bucket,
      case
        when current_streak = 0 then 0
        when current_streak between 1 and 2 then 1
        when current_streak between 3 and 6 then 2
        when current_streak between 7 and 13 then 3
        when current_streak between 14 and 29 then 4
        else 5
      end as bucket_order
    from profiles
  )
  select bucket, count(*)::int as users, bucket_order
  from b group by bucket, bucket_order
  order by bucket_order;
$$;

-- Achievement unlock distribution (how many users earned each badge).
create or replace function admin_achievement_distribution()
returns table(key text, name text, icon text, unlocks int, sort_order int)
language sql security definer set search_path = public stable as $$
  select a.key, a.name, a.icon,
         count(ua.user_id)::int as unlocks, a.sort_order
  from achievements a
  left join user_achievements ua on ua.achievement_key = a.key
  group by a.key, a.name, a.icon, a.sort_order
  order by a.sort_order;
$$;

-- Contact spiritual-journey funnel (counts per spiritual_status).
create or replace function admin_contact_funnel()
returns table(status text, contacts int, step_order int)
language sql security definer set search_path = public stable as $$
  with ordered as (
    select 'new_contact' as status, 1 as step_order
    union all select 'accepted_christ', 2
    union all select 'followup_started', 3
    union all select 'connected_to_church', 4
    union all select 'active', 5
  )
  select o.status,
         (select count(*) from contacts c where c.status::text = o.status)::int as contacts,
         o.step_order
  from ordered o
  order by o.step_order;
$$;

-- =============================================================================
-- 3. COMMUNITY & CONTENT
-- =============================================================================

-- Daily posts split by type (stacked area). Gap-filled.
create or replace function admin_daily_posts(p_days int default 30)
returns table(
  day date,
  testimony int,
  outreach int,
  prayer int,
  salvation int,
  update_ int,
  total int
)
language sql security definer set search_path = public stable as $$
  with days as (
    select generate_series(
      (current_date - (p_days - 1)), current_date, interval '1 day'
    )::date as day
  ),
  agg as (
    select date_trunc('day', created_at)::date as day, type, count(*)::int as n
    from posts
    where created_at >= (current_date - (p_days - 1))
    group by 1, 2
  )
  select
    d.day,
    coalesce(sum(n) filter (where type = 'testimony'), 0)::int,
    coalesce(sum(n) filter (where type = 'outreach'), 0)::int,
    coalesce(sum(n) filter (where type = 'prayer'), 0)::int,
    coalesce(sum(n) filter (where type = 'salvation'), 0)::int,
    coalesce(sum(n) filter (where type = 'update'), 0)::int,
    coalesce(sum(n), 0)::int
  from days d
  left join agg a using (day)
  group by d.day
  order by d.day;
$$;

-- Post type mix (donut) all-time.
create or replace function admin_post_type_mix()
returns table(type text, n int)
language sql security definer set search_path = public stable as $$
  select type::text, count(*)::int from posts group by 1 order by 2 desc;
$$;

-- Reaction sentiment mix (donut) all-time.
create or replace function admin_reaction_mix()
returns table(reaction text, n int)
language sql security definer set search_path = public stable as $$
  select reaction::text, count(*)::int from post_reactions group by 1 order by 2 desc;
$$;

-- Community KPIs in one shot.
create or replace function admin_community_stats()
returns table(
  total_posts int,
  posts_7d int,
  total_reactions int,
  total_comments int,
  avg_reactions numeric,
  avg_comments numeric
)
language sql security definer set search_path = public stable as $$
  select
    (select count(*) from posts)::int,
    (select count(*) from posts where created_at >= current_date - 6)::int,
    (select count(*) from post_reactions)::int,
    (select count(*) from comments)::int,
    round((select count(*)::numeric from post_reactions) / nullif((select count(*) from posts), 0), 1),
    round((select count(*)::numeric from comments) / nullif((select count(*) from posts), 0), 1);
$$;

-- Top posts by engagement (reactions + comments).
create or replace function admin_top_posts(p_limit int default 10)
returns table(
  id uuid,
  body text,
  type text,
  author text,
  created_at timestamptz,
  reactions int,
  comments int,
  engagement int
)
language sql security definer set search_path = public stable as $$
  select
    p.id, p.body, p.type::text,
    coalesce(pr.full_name, '—') as author,
    p.created_at,
    coalesce(r.n, 0)::int as reactions,
    coalesce(c.n, 0)::int as comments,
    (coalesce(r.n, 0) + coalesce(c.n, 0))::int as engagement
  from posts p
  left join profiles pr on pr.id = p.author_id
  left join (select post_id, count(*) n from post_reactions group by 1) r on r.post_id = p.id
  left join (select post_id, count(*) n from comments group by 1) c on c.post_id = p.id
  order by engagement desc, p.created_at desc
  limit p_limit;
$$;

-- =============================================================================
-- 4. MAP  (geo points for the map view — extracts lat/lng from geography)
-- =============================================================================

-- Recent activity points for the heatmap (last N days, capped).
create or replace function admin_geo_activity(p_days int default 30, p_limit int default 2000)
returns table(lat double precision, lng double precision, type text, occurred_at timestamptz)
language sql security definer set search_path = public stable as $$
  select st_y(location::geometry) as lat, st_x(location::geometry) as lng,
         type::text, occurred_at
  from activity_logs
  where location is not null
    and occurred_at >= (current_date - (p_days - 1))
  order by occurred_at desc
  limit p_limit;
$$;

-- All churches with coordinates (markers).
create or replace function admin_geo_churches()
returns table(
  id uuid, name text, city text, is_verified boolean,
  claim_status text, lat double precision, lng double precision
)
language sql security definer set search_path = public stable as $$
  select id, name, city, is_verified, claim_status,
         st_y(location::geometry), st_x(location::geometry)
  from churches
  where location is not null;
$$;

-- Live evangelists right now (fuzzed to ~110m for privacy, same as the app).
create or replace function admin_geo_live()
returns table(lat double precision, lng double precision)
language sql security definer set search_path = public stable as $$
  select round(st_y(location::geometry)::numeric, 3)::double precision,
         round(st_x(location::geometry)::numeric, 3)::double precision
  from live_presence
  where is_evangelizing = true and expires_at > now() and location is not null;
$$;

-- Recent located posts (markers).
create or replace function admin_geo_posts(p_days int default 30, p_limit int default 500)
returns table(id uuid, type text, lat double precision, lng double precision, created_at timestamptz)
language sql security definer set search_path = public stable as $$
  select id, type::text, st_y(location::geometry), st_x(location::geometry), created_at
  from posts
  where location is not null and created_at >= (current_date - (p_days - 1))
  order by created_at desc
  limit p_limit;
$$;

-- Per-city rollup for the map side panel.
create or replace function admin_city_rollup(p_limit int default 25)
returns table(
  city text,
  users int,
  salvations int,
  conversations int,
  churches int,
  active_now int
)
language sql security definer set search_path = public stable as $$
  with cities as (
    select distinct coalesce(nullif(trim(city), ''), 'Unknown') as city from profiles
    union
    select distinct coalesce(nullif(trim(city), ''), 'Unknown') from churches
  )
  select
    ci.city,
    (select count(*) from profiles p where coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select coalesce(sum(p.total_salvations),0) from profiles p where coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select coalesce(sum(p.total_conversations),0) from profiles p where coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select count(*) from churches c where coalesce(nullif(trim(c.city),''),'Unknown') = ci.city)::int,
    0::int  -- active_now is computed live elsewhere; placeholder for symmetry
  from cities ci
  order by 2 desc
  limit p_limit;
$$;

-- =============================================================================
-- 5. OVERVIEW EXTRAS  (live count + recent pulse)
-- =============================================================================

create or replace function admin_live_count()
returns int
language sql security definer set search_path = public stable as $$
  select count(*)::int from live_presence
  where is_evangelizing = true and expires_at > now();
$$;

-- Headline KPIs plus their value in the prior period (for WoW deltas).
create or replace function admin_kpi_overview()
returns table(
  total_users int, users_7d int, users_prev_7d int,
  total_salvations int, total_conversations int, total_prayers int,
  total_posts int, posts_7d int, posts_prev_7d int,
  total_churches int, verified_churches int,
  live_now int
)
language sql security definer set search_path = public stable as $$
  select
    (select count(*) from profiles)::int,
    (select count(*) from profiles where created_at >= current_date - 6)::int,
    (select count(*) from profiles where created_at >= current_date - 13 and created_at < current_date - 6)::int,
    (select coalesce(sum(total_salvations),0) from profiles)::int,
    (select coalesce(sum(total_conversations),0) from profiles)::int,
    (select count(*) from activity_logs where type = 'prayer')::int,
    (select count(*) from posts)::int,
    (select count(*) from posts where created_at >= current_date - 6)::int,
    (select count(*) from posts where created_at >= current_date - 13 and created_at < current_date - 6)::int,
    (select count(*) from churches)::int,
    (select count(*) from churches where is_verified)::int,
    (select count(*) from live_presence where is_evangelizing = true and expires_at > now())::int;
$$;

-- =============================================================================
-- GRANTS — service role only (admin web server). NOT to `authenticated`.
-- =============================================================================
do $$
declare fn text;
begin
  for fn in
    select format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;
