-- =====================================================================
-- Go and Tell — Tell real accounts apart from guest sessions
-- Idempotent. Run AFTER migrate_admin_analytics.sql (safe to re-run).
--
-- The app opens as a guest: every fresh install signs in anonymously, and
-- the handle_new_user trigger gives that anonymous auth user a profiles row.
-- The admin dashboard was counting those rows as users, so 39 "users" were
-- really two people plus dozens of guest sessions from testing.
--
-- Fix: profiles.is_guest mirrors auth.users.is_anonymous (set on creation,
-- flipped to false the moment a guest upgrades to a real account), and every
-- admin rollup that counts people ignores guests.
-- =====================================================================

-- ---------- 1. The flag ----------
alter table profiles add column if not exists is_guest boolean not null default false;
create index if not exists idx_profiles_is_guest on profiles (is_guest);

-- Backfill from the auth table (service role / SQL editor can read it).
update profiles p
set is_guest = coalesce(u.is_anonymous, false)
from auth.users u
where u.id = p.id
  and p.is_guest is distinct from coalesce(u.is_anonymous, false);

-- ---------- 2. Keep it in sync ----------
-- New auth user → profile row carries the anonymous flag.
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, is_guest)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Evangelist'),
    coalesce(new.is_anonymous, false)
  )
  on conflict (id) do update set is_guest = excluded.is_guest;
  return new;
end; $$;

-- Guest upgrades (link email / Apple / Google to the same user) flip
-- auth.users.is_anonymous to false; mirror that onto the profile.
create or replace function sync_profile_guest_flag()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_anonymous is distinct from old.is_anonymous then
    update profiles set is_guest = coalesce(new.is_anonymous, false) where id = new.id;
  end if;
  return new;
end; $$;

drop trigger if exists on_auth_user_guest_flag on auth.users;
create trigger on_auth_user_guest_flag
  after update of is_anonymous on auth.users
  for each row execute function sync_profile_guest_flag();

-- ---------- 3. Admin rollups: count people, not guest sessions ----------
create or replace function admin_guest_count()
returns int
language sql security definer set search_path = public stable as $$
  select count(*)::int from profiles where is_guest;
$$;

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
    where not is_guest
      and created_at >= (current_date - (p_days - 1))
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

create or replace function admin_signups_by_source(p_days int default 30)
returns table(source text, signups int)
language sql security definer set search_path = public stable as $$
  select
    coalesce(nullif(trim(signup_source), ''), 'unknown') as source,
    count(*)::int as signups
  from profiles
  where not is_guest
    and created_at >= (current_date - (p_days - 1))
  group by 1
  order by 2 desc;
$$;

create or replace function admin_signups_by_city(p_days int default 30, p_limit int default 12)
returns table(city text, signups int)
language sql security definer set search_path = public stable as $$
  select
    coalesce(nullif(trim(city), ''), 'Unknown') as city,
    count(*)::int as signups
  from profiles
  where not is_guest
    and created_at >= (current_date - (p_days - 1))
  group by 1
  order by 2 desc
  limit p_limit;
$$;

create or replace function admin_activation_rate(p_days int default 30, p_window_days int default 7)
returns table(signups int, activated int, rate numeric)
language sql security definer set search_path = public stable as $$
  with cohort as (
    select id, created_at
    from profiles
    where not is_guest
      and created_at >= (current_date - (p_days - 1))
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
    where not is_guest
      and created_at >= date_trunc('week', current_date) - ((p_weeks - 1) || ' weeks')::interval
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

create or replace function admin_product_funnel()
returns table(stage text, users int, step_order int)
language sql security definer set search_path = public stable as $$
  select 'Signed up' as stage,
         (select count(*) from profiles where not is_guest)::int as users, 1 as step_order
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
  where not is_guest
  order by metric desc nulls last
  limit p_limit;
$$;

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
    where not is_guest
  )
  select bucket, count(*)::int as users, bucket_order
  from b group by bucket, bucket_order
  order by bucket_order;
$$;

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
    select distinct coalesce(nullif(trim(city), ''), 'Unknown') as city from profiles where not is_guest
    union
    select distinct coalesce(nullif(trim(city), ''), 'Unknown') from churches
  )
  select
    ci.city,
    (select count(*) from profiles p where not p.is_guest and coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select coalesce(sum(p.total_salvations),0) from profiles p where not p.is_guest and coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select coalesce(sum(p.total_conversations),0) from profiles p where not p.is_guest and coalesce(nullif(trim(p.city),''),'Unknown') = ci.city)::int,
    (select count(*) from churches c where coalesce(nullif(trim(c.city),''),'Unknown') = ci.city)::int,
    0::int
  from cities ci
  order by 2 desc
  limit p_limit;
$$;

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
    (select count(*) from profiles where not is_guest)::int,
    (select count(*) from profiles where not is_guest and created_at >= current_date - 6)::int,
    (select count(*) from profiles where not is_guest and created_at >= current_date - 13 and created_at < current_date - 6)::int,
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

-- ---------- 4. Grants: admin functions stay service-role only ----------
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

notify pgrst, 'reload schema';
