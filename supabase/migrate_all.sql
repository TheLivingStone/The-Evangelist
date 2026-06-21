-- =====================================================================
-- The Evangelist — ONE-SHOT Clerk migration.
-- Paste this ENTIRE file into the Supabase SQL Editor and Run once.
-- It runs: reset (drop old) -> schema (create) -> policies (RLS+RPCs).
-- Re-runnable: safe to run again from any half-migrated state.
-- =====================================================================

-- ########## 1/3 RESET ##########
-- =====================================================================
-- The Evangelist — DESTRUCTIVE reset (run FIRST, before schema.sql).
--
-- Drops every object the app owns so schema.sql + policies.sql can recreate
-- them cleanly. Use this when migrating the existing (uuid/Supabase-Auth)
-- database to the Clerk-based schema (profiles.id as text, auth.jwt()->>'sub').
--
-- ⚠️  This DELETES ALL DATA in these tables. Safe here because the project has
--     no real users yet — only the achievement/verse seeds, which schema.sql
--     re-inserts. Do NOT run this against a database with real user data.
--
-- Run order:  reset.sql  →  schema.sql  →  policies.sql
-- =====================================================================

-- ---------- Old auth trigger (Clerk users never touch auth.users) ----------
-- The original deploy added this trigger + function; remove them.
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists handle_new_user() cascade;

-- ---------- View ----------
drop view if exists post_reaction_counts cascade;

-- ---------- Tables (cascade clears FKs, indexes, policies, triggers) ----------
drop table if exists devices            cascade;
drop table if exists notifications      cascade;
drop table if exists daily_missions     cascade;
drop table if exists verses             cascade;
drop table if exists user_achievements  cascade;
drop table if exists achievements       cascade;
drop table if exists group_members      cascade;
drop table if exists groups             cascade;
drop table if exists live_presence      cascade;
drop table if exists comments           cascade;
drop table if exists post_reactions     cascade;
drop table if exists posts              cascade;
drop table if exists event_attendees    cascade;
drop table if exists events             cascade;
drop table if exists churches           cascade;
drop table if exists activity_logs      cascade;
drop table if exists outreach_sessions  cascade;
drop table if exists followups          cascade;
drop table if exists contacts           cascade;
drop table if exists profiles           cascade;

-- ---------- Functions / RPCs ----------
drop function if exists apply_activity_stats() cascade;
drop function if exists touch_updated_at() cascade;
drop function if exists nearby_evangelists(double precision, double precision, int) cascade;
drop function if exists nearby_churches(double precision, double precision, int) cascade;
drop function if exists area_stats(double precision, double precision, int) cascade;
drop function if exists end_session(uuid, int, int, int) cascade;

-- ---------- Enums ----------
drop type if exists spiritual_status cascade;
drop type if exists activity_type    cascade;
drop type if exists post_type        cascade;
drop type if exists reaction_type    cascade;
drop type if exists followup_status  cascade;
drop type if exists session_status   cascade;

-- Extensions (pgcrypto, postgis, pg_cron) are intentionally left installed.

-- ########## 2/3 SCHEMA ##########
-- =====================================================================
-- The Evangelist — Database schema (Supabase / Postgres 15+)
-- Run this file FIRST, then run policies.sql.
-- =====================================================================

-- ---------- Extensions ----------
create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "postgis";       -- geography/geometry for the live map
create extension if not exists "pg_cron";       -- scheduled follow-ups & daily missions (enable in Supabase dashboard)

-- ---------- Enums ----------
create type spiritual_status as enum
  ('new_contact','accepted_christ','followup_started','connected_to_church','active');

create type activity_type as enum
  ('conversation','salvation','prayer','followup','church_connection');

create type post_type as enum
  ('testimony','outreach','prayer','salvation','update');

create type reaction_type as enum
  ('encouraged','inspired','praying','amen');

create type followup_status as enum
  ('scheduled','sent','replied','skipped');

create type session_status as enum
  ('live','completed','cancelled');

-- =====================================================================
-- PROFILES  (1:1 with a Clerk user)
-- id holds the Clerk user id (the JWT 'sub' claim, e.g. 'user_abc123').
-- Identity lives in Clerk, not auth.users, so there is no FK to auth.users
-- and no on_auth_user_created trigger — the app upserts this row on first
-- authenticated launch (see lib/repositories ProfileRepo.ensure()).
-- =====================================================================
create table profiles (
  id                       text primary key,
  full_name                text not null,
  username                 text unique,
  city                     text,
  church                   text,
  ministry                 text,
  bio                      text,
  avatar_url               text,
  -- privacy / settings
  is_visible_on_map        boolean not null default true,
  daily_reminder_enabled   boolean not null default true,
  theme                    text not null default 'dark',          -- 'dark' | 'light'
  -- cached gamification stats (kept in sync by triggers)
  current_streak           int not null default 0,
  longest_streak           int not null default 0,
  last_evangelism_date     date,
  weekly_goal              int not null default 5,
  total_conversations      int not null default 0,
  total_salvations         int not null default 0,
  total_followups          int not null default 0,
  total_church_connections int not null default 0,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);
comment on table profiles is 'Public-facing user profile; id = Clerk user id (JWT sub). Stats are denormalised caches maintained by triggers.';

-- =====================================================================
-- CONTACTS  ("My People" — the evangelism CRM)
-- =====================================================================
create table contacts (
  id               uuid primary key default gen_random_uuid(),
  owner_id         text not null references profiles(id) on delete cascade,
  first_name       text not null,
  last_name        text,
  phone            text,
  email            text,
  city             text,
  met_location     text,
  date_met         date not null default current_date,
  status           spiritual_status not null default 'new_contact',
  selfie_url       text,
  notes            text,
  next_followup_at date,
  tags             text[] not null default '{}',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index idx_contacts_owner       on contacts(owner_id);
create index idx_contacts_next_followup on contacts(owner_id, next_followup_at);
create index idx_contacts_status       on contacts(owner_id, status);

-- =====================================================================
-- FOLLOWUPS  (scheduled touchpoints tied to a contact)
-- =====================================================================
create table followups (
  id           uuid primary key default gen_random_uuid(),
  contact_id   uuid not null references contacts(id) on delete cascade,
  owner_id     text not null references profiles(id) on delete cascade,
  day_offset   int not null,                         -- 1, 3, 7, 14, 30 (or custom)
  title        text not null,                        -- 'Welcome message', 'Church recommendation', ...
  message      text,                                 -- AI-drafted or user-edited body
  scheduled_for date not null,
  sent_at      timestamptz,
  status       followup_status not null default 'scheduled',
  channel      text default 'sms',                   -- 'sms' | 'whatsapp' | 'in_app'
  created_at   timestamptz not null default now()
);
create index idx_followups_owner_due on followups(owner_id, scheduled_for) where status = 'scheduled';
create index idx_followups_contact   on followups(contact_id);

-- =====================================================================
-- OUTREACH SESSIONS  (timed "I'm out evangelising now")
-- =====================================================================
create table outreach_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           text not null references profiles(id) on delete cascade,
  started_at        timestamptz not null default now(),
  ended_at          timestamptz,
  duration_seconds  int,
  location          geography(Point,4326),           -- where the session started
  location_name     text,
  conversations_count int not null default 0,
  prayers_count       int not null default 0,
  people_added_count  int not null default 0,
  status            session_status not null default 'live',
  created_at        timestamptz not null default now()
);
create index idx_sessions_user on outreach_sessions(user_id, started_at desc);
create index idx_sessions_live on outreach_sessions(status) where status = 'live';

-- =====================================================================
-- ACTIVITY LOGS  (atomic record — source of truth for all stats & streaks)
-- =====================================================================
create table activity_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     text not null references profiles(id) on delete cascade,
  type        activity_type not null,
  contact_id  uuid references contacts(id) on delete set null,
  session_id  uuid references outreach_sessions(id) on delete set null,
  church_id   uuid,                                   -- set for church_connection (FK added below)
  note        text,
  location    geography(Point,4326),
  occurred_at timestamptz not null default now()
);
create index idx_logs_user_time on activity_logs(user_id, occurred_at desc);
create index idx_logs_type      on activity_logs(user_id, type);

-- =====================================================================
-- CHURCHES  (directory; new believers connect here)
-- =====================================================================
create table churches (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null,
  location           geography(Point,4326),
  address            text,
  city               text,
  service_times      text,
  website            text,
  statement_of_faith text,
  contact_info       text,
  claimed_by         text references profiles(id) on delete set null,
  is_verified        boolean not null default false,
  created_at         timestamptz not null default now()
);
create index idx_churches_geo on churches using gist(location);

-- add the deferred FK from activity_logs.church_id
alter table activity_logs
  add constraint fk_logs_church foreign key (church_id) references churches(id) on delete set null;

-- =====================================================================
-- EVENTS  (outreach events; "Join Outreach")
-- =====================================================================
create table events (
  id            uuid primary key default gen_random_uuid(),
  host_id       text not null references profiles(id) on delete cascade,
  title         text not null,
  description   text,
  location      geography(Point,4326),
  location_name text,
  starts_at     timestamptz not null,
  created_at    timestamptz not null default now()
);
create index idx_events_geo  on events using gist(location);
create index idx_events_time on events(starts_at);

create table event_attendees (
  event_id  uuid not null references events(id) on delete cascade,
  user_id   text not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- =====================================================================
-- COMMUNITY: POSTS, REACTIONS, COMMENTS
-- =====================================================================
create table posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   text not null references profiles(id) on delete cascade,
  type        post_type not null default 'testimony',
  body        text not null,
  photo_url   text,
  city        text,
  event_id    uuid references events(id) on delete set null,   -- for outreach posts
  location    geography(Point,4326),                            -- enables "Nearby" feed
  is_public   boolean not null default true,
  created_at  timestamptz not null default now()
);
create index idx_posts_time on posts(created_at desc);
create index idx_posts_type on posts(type, created_at desc);
create index idx_posts_geo  on posts using gist(location);
create index idx_posts_author on posts(author_id, created_at desc);

create table post_reactions (
  post_id    uuid not null references posts(id) on delete cascade,
  user_id    text not null references profiles(id) on delete cascade,
  reaction   reaction_type not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, reaction)
);
create index idx_reactions_post on post_reactions(post_id);

create table comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts(id) on delete cascade,
  author_id  text not null references profiles(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index idx_comments_post on comments(post_id, created_at);

-- =====================================================================
-- LIVE PRESENCE  (geo-queryable backing store for the live map)
-- Realtime Presence handles instant pin updates; this table powers
-- the nearby_evangelists() geo query and survives reconnects.
-- =====================================================================
create table live_presence (
  user_id         text primary key references profiles(id) on delete cascade,
  location        geography(Point,4326) not null,
  is_evangelizing boolean not null default true,
  session_id      uuid references outreach_sessions(id) on delete set null,
  updated_at      timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '5 minutes'
);
create index idx_presence_geo     on live_presence using gist(location);
create index idx_presence_expires on live_presence(expires_at);

-- =====================================================================
-- GROUPS  (ministries / teams shown on profiles)
-- =====================================================================
create table groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  city        text,
  description text,
  created_by  text references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create table group_members (
  group_id  uuid not null references groups(id) on delete cascade,
  user_id   text not null references profiles(id) on delete cascade,
  role      text not null default 'member',          -- 'member' | 'leader'
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

-- =====================================================================
-- ACHIEVEMENTS  (catalog + per-user unlocks)
-- =====================================================================
create table achievements (
  key         text primary key,                       -- 'first_conversation', '7_day_streak', ...
  name        text not null,
  description text,
  icon        text,                                    -- emoji or asset key
  sort_order  int not null default 0
);
create table user_achievements (
  user_id        text not null references profiles(id) on delete cascade,
  achievement_key text not null references achievements(key) on delete cascade,
  earned_at      timestamptz not null default now(),
  primary key (user_id, achievement_key)
);

-- =====================================================================
-- DAILY ENCOURAGEMENT  (verse catalog + per-user daily mission)
-- =====================================================================
create table verses (
  id        uuid primary key default gen_random_uuid(),
  text      text not null,
  reference text not null,
  theme     text
);
create table daily_missions (
  user_id    text not null references profiles(id) on delete cascade,
  mission_date date not null default current_date,
  verse_id   uuid references verses(id),
  tasks      jsonb not null default '[]',              -- [{label, done}]
  completed  boolean not null default false,
  primary key (user_id, mission_date)
);

-- =====================================================================
-- NOTIFICATIONS + DEVICE TOKENS (push)
-- =====================================================================
create table notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    text not null references profiles(id) on delete cascade,
  type       text not null,                            -- 'followup_due','encouraged','event_reminder',...
  title      text not null,
  body       text,
  data       jsonb not null default '{}',
  read       boolean not null default false,
  created_at timestamptz not null default now()
);
create index idx_notifications_user on notifications(user_id, created_at desc) where read = false;

create table devices (
  id         uuid primary key default gen_random_uuid(),
  user_id    text not null references profiles(id) on delete cascade,
  fcm_token  text not null unique,
  platform   text not null,                            -- 'ios' | 'android'
  created_at timestamptz not null default now()
);

-- =====================================================================
-- TRIGGERS & FUNCTIONS
-- =====================================================================

-- NOTE: Identity is owned by Clerk, not Supabase Auth. Clerk users never
-- create an auth.users row, so the old on_auth_user_created trigger is gone.
-- The Flutter app upserts a profiles row on first authenticated launch
-- (ProfileRepo.ensure), using the Clerk user id (JWT 'sub') as profiles.id.

-- Keep updated_at fresh.
create or replace function touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger trg_profiles_touch before update on profiles
  for each row execute function touch_updated_at();
create trigger trg_contacts_touch before update on contacts
  for each row execute function touch_updated_at();

-- Recompute stats + streak whenever an activity is logged.
-- Streak = consecutive days (ending today/yesterday) with >=1 activity.
create or replace function apply_activity_stats()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  d date := (new.occurred_at at time zone 'utc')::date;
  last_date date;
begin
  -- bump the matching lifetime counter
  update profiles set
    total_conversations      = total_conversations      + (new.type = 'conversation')::int,
    total_salvations         = total_salvations         + (new.type = 'salvation')::int,
    total_followups          = total_followups          + (new.type = 'followup')::int,
    total_church_connections = total_church_connections + (new.type = 'church_connection')::int
  where id = new.user_id;

  -- streak logic
  select last_evangelism_date into last_date from profiles where id = new.user_id;
  if last_date is null or d - last_date >= 2 then
     update profiles set current_streak = 1, last_evangelism_date = d where id = new.user_id;
  elsif d - last_date = 1 then
     update profiles set current_streak = current_streak + 1, last_evangelism_date = d where id = new.user_id;
  end if; -- same day: no change

  update profiles set longest_streak = greatest(longest_streak, current_streak)
    where id = new.user_id;

  return new;
end; $$;

create trigger trg_activity_stats after insert on activity_logs
  for each row execute function apply_activity_stats();

-- Atomically complete a live session and fan its counters out to activity logs.
create or replace function end_session(
  p_session_id uuid,
  p_conversations int default 0,
  p_prayers int default 0,
  p_people_added int default 0
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_user_id text;
begin
  if least(p_conversations, p_prayers, p_people_added) < 0 then
    raise exception 'Session counters cannot be negative';
  end if;

  update outreach_sessions
  set ended_at = now(),
      duration_seconds = greatest(0, extract(epoch from now() - started_at)::int),
      conversations_count = p_conversations,
      prayers_count = p_prayers,
      people_added_count = p_people_added,
      status = 'completed'
  where id = p_session_id
    and user_id = auth.jwt() ->> 'sub'
    and status = 'live'
  returning user_id into v_user_id;

  if v_user_id is null then
    raise exception 'Live session not found';
  end if;

  insert into activity_logs(user_id, type, session_id)
    select v_user_id, 'conversation'::activity_type, p_session_id
    from generate_series(1, p_conversations);
  insert into activity_logs(user_id, type, session_id)
    select v_user_id, 'prayer'::activity_type, p_session_id
    from generate_series(1, p_prayers);
  delete from live_presence where user_id = v_user_id;
end; $$;

-- Convenience view: reaction counts per post.
create view post_reaction_counts as
  select post_id, reaction, count(*)::int as cnt
  from post_reactions group by post_id, reaction;

-- =====================================================================
-- SEED: achievements + a few verses
-- =====================================================================
insert into achievements(key,name,description,icon,sort_order) values
  ('first_conversation','First Conversation','Logged your first Gospel conversation','💬',1),
  ('first_salvation','First Salvation','Recorded your first salvation','✝️',2),
  ('first_followup','First Follow-Up','Completed your first follow-up','📩',3),
  ('7_day_streak','7 Day Streak','Shared the Gospel 7 days in a row','🔥',4),
  ('30_day_streak','30 Day Streak','Shared the Gospel 30 days in a row','🏅',5),
  ('100_conversations','100 Conversations','Reached 100 Gospel conversations','💯',6),
  ('faithful_followup','Faithful Follow-Up','Completed 25 follow-ups','🤝',7)
on conflict (key) do nothing;

insert into verses(text,reference,theme) values
  ('Go into all the world and proclaim the gospel to the whole creation.','Mark 16:15','commission'),
  ('You will receive power when the Holy Spirit has come upon you, and you will be my witnesses.','Acts 1:8','boldness'),
  ('How beautiful are the feet of those who bring good news!','Romans 10:15','encouragement'),
  ('Let your light shine before others, that they may see your good works and glorify your Father.','Matthew 5:16','witness')
on conflict do nothing;

-- ########## 3/3 POLICIES ##########
-- =====================================================================
-- The Evangelist — Row-Level Security policies + helper RPCs
-- Run this file AFTER schema.sql.
-- Model: identity is provided by CLERK via Supabase's native third-party
-- auth integration. The app sends the anon (publishable) key + the Clerk
-- session JWT. The current user's id is the Clerk 'sub' claim, read with
--   auth.jwt()->>'sub'   (a text value like 'user_abc123').
-- (auth.jwt()->>'sub') is NOT used — it returns the Supabase uuid, which is null here.
-- Privileged jobs use the service role, which bypasses RLS.
-- =====================================================================

-- Enable RLS on every table.
alter table profiles          enable row level security;
alter table contacts          enable row level security;
alter table followups         enable row level security;
alter table outreach_sessions enable row level security;
alter table activity_logs     enable row level security;
alter table churches          enable row level security;
alter table events            enable row level security;
alter table event_attendees   enable row level security;
alter table posts             enable row level security;
alter table post_reactions    enable row level security;
alter table comments          enable row level security;
alter table live_presence     enable row level security;
alter table groups            enable row level security;
alter table group_members     enable row level security;
alter table user_achievements enable row level security;
alter table daily_missions    enable row level security;
alter table notifications     enable row level security;
alter table devices           enable row level security;
alter table achievements      enable row level security;
alter table verses            enable row level security;

-- ---------- PROFILES ----------
-- Anyone signed in can read public profiles (Community, public profile page).
create policy "profiles are readable by authenticated users"
  on profiles for select to authenticated using (true);
-- The app upserts the caller's own profile on first launch (id must equal the
-- Clerk user id), since there is no longer a DB trigger creating profile rows.
create policy "users insert their own profile"
  on profiles for insert to authenticated with check (id = (auth.jwt()->>'sub'));
create policy "users update their own profile"
  on profiles for update to authenticated using (id = (auth.jwt()->>'sub')) with check (id = (auth.jwt()->>'sub'));

-- ---------- CONTACTS (owner-only, fully private) ----------
create policy "owner can read contacts"   on contacts for select to authenticated using (owner_id = (auth.jwt()->>'sub'));
create policy "owner can insert contacts" on contacts for insert to authenticated with check (owner_id = (auth.jwt()->>'sub'));
create policy "owner can update contacts" on contacts for update to authenticated using (owner_id = (auth.jwt()->>'sub'));
create policy "owner can delete contacts" on contacts for delete to authenticated using (owner_id = (auth.jwt()->>'sub'));

-- ---------- FOLLOWUPS (owner-only) ----------
create policy "owner rw followups"
  on followups for all to authenticated using (owner_id = (auth.jwt()->>'sub')) with check (owner_id = (auth.jwt()->>'sub'));

-- ---------- OUTREACH SESSIONS (owner-only) ----------
create policy "owner rw sessions"
  on outreach_sessions for all to authenticated using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

-- ---------- ACTIVITY LOGS (owner can insert/read own; append-only) ----------
create policy "owner read logs"   on activity_logs for select to authenticated using (user_id = (auth.jwt()->>'sub'));
create policy "owner insert logs" on activity_logs for insert to authenticated with check (user_id = (auth.jwt()->>'sub'));
-- (no update/delete policies => append-only for clients)

-- ---------- CHURCHES (public read; authed create; claimant edits) ----------
create policy "churches public read" on churches for select to authenticated using (true);
create policy "authed add church"    on churches for insert to authenticated with check ((auth.jwt()->>'sub') is not null);
create policy "claimant edits church" on churches for update to authenticated using (claimed_by = (auth.jwt()->>'sub'));

-- ---------- EVENTS (public read; host manages) ----------
create policy "events public read" on events for select to authenticated using (true);
create policy "host manages events" on events for all to authenticated
  using (host_id = (auth.jwt()->>'sub')) with check (host_id = (auth.jwt()->>'sub'));

create policy "attendees readable" on event_attendees for select to authenticated using (true);
create policy "join/leave own"     on event_attendees for all to authenticated
  using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

-- ---------- POSTS (public read; author writes) ----------
create policy "public posts readable" on posts for select to authenticated using (is_public = true or author_id = (auth.jwt()->>'sub'));
create policy "author creates post"   on posts for insert to authenticated with check (author_id = (auth.jwt()->>'sub'));
create policy "author edits post"     on posts for update to authenticated using (author_id = (auth.jwt()->>'sub'));
create policy "author deletes post"   on posts for delete to authenticated using (author_id = (auth.jwt()->>'sub'));

-- ---------- REACTIONS & COMMENTS (public read; own writes) ----------
create policy "reactions readable" on post_reactions for select to authenticated using (true);
create policy "own reactions"      on post_reactions for all to authenticated
  using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

create policy "comments readable" on comments for select to authenticated using (true);
create policy "author writes comment" on comments for insert to authenticated with check (author_id = (auth.jwt()->>'sub'));
create policy "author edits comment"  on comments for update to authenticated using (author_id = (auth.jwt()->>'sub'));
create policy "author deletes comment" on comments for delete to authenticated using (author_id = (auth.jwt()->>'sub'));

-- ---------- LIVE PRESENCE (write own only; NO direct select) ----------
-- Clients never SELECT this table directly. They get fuzzed locations via
-- the nearby_evangelists() RPC, which respects is_visible_on_map.
create policy "upsert own presence" on live_presence for insert to authenticated with check (user_id = (auth.jwt()->>'sub'));
create policy "update own presence" on live_presence for update to authenticated using (user_id = (auth.jwt()->>'sub'));
create policy "delete own presence" on live_presence for delete to authenticated using (user_id = (auth.jwt()->>'sub'));
-- (deliberately no SELECT policy)

-- ---------- GROUPS ----------
create policy "groups public read" on groups for select to authenticated using (true);
create policy "creator manages group" on groups for all to authenticated
  using (created_by = (auth.jwt()->>'sub')) with check (created_by = (auth.jwt()->>'sub'));
create policy "members readable" on group_members for select to authenticated using (true);
create policy "join/leave groups" on group_members for all to authenticated
  using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

-- ---------- ACHIEVEMENTS ----------
create policy "achievement catalog readable" on achievements for select to authenticated using (true);
create policy "verse catalog readable"       on verses for select to authenticated using (true);
create policy "own achievements readable"    on user_achievements for select to authenticated using (user_id = (auth.jwt()->>'sub'));
-- user_achievements are written by service-role (award logic), not clients.

-- ---------- DAILY MISSIONS (owner-only) ----------
create policy "owner rw missions" on daily_missions for all to authenticated
  using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

-- ---------- NOTIFICATIONS (owner read/update; created by service role) ----------
create policy "owner reads notifications"   on notifications for select to authenticated using (user_id = (auth.jwt()->>'sub'));
create policy "owner updates notifications" on notifications for update to authenticated using (user_id = (auth.jwt()->>'sub'));

-- ---------- DEVICES (owner-only) ----------
create policy "owner rw devices" on devices for all to authenticated
  using (user_id = (auth.jwt()->>'sub')) with check (user_id = (auth.jwt()->>'sub'));

-- =====================================================================
-- PRIVACY-PRESERVING RPCs (security definer = run as owner, bypass RLS,
-- but only return what we explicitly allow).
-- =====================================================================

-- Nearby evangelists for the live map. Returns FUZZED locations only,
-- for users who are currently live, not expired, and map-visible.
create or replace function nearby_evangelists(lat double precision, lng double precision, radius_m int default 5000)
returns table (
  user_id text, full_name text, avatar_url text,
  approx_lat double precision, approx_lng double precision, distance_m double precision
)
language sql security definer set search_path = public stable as $$
  select p.id, p.full_name, p.avatar_url,
         -- round to ~3 decimal places (~110m) so exact location is never exposed
         round(st_y(lp.location::geometry)::numeric, 3)::double precision as approx_lat,
         round(st_x(lp.location::geometry)::numeric, 3)::double precision as approx_lng,
         st_distance(lp.location, st_point(lng, lat)::geography) as distance_m
  from live_presence lp
  join profiles p on p.id = lp.user_id
  where lp.is_evangelizing
    and lp.expires_at > now()
    and p.is_visible_on_map
    and p.id <> (auth.jwt()->>'sub')
    and st_dwithin(lp.location, st_point(lng, lat)::geography, radius_m)
  order by distance_m
  limit 100;
$$;

-- Churches near a point (public directory; exact location is fine here).
create or replace function nearby_churches(lat double precision, lng double precision, radius_m int default 8000)
returns table (id uuid, name text, city text, distance_m double precision, lat double precision, lng double precision)
language sql security definer set search_path = public stable as $$
  select c.id, c.name, c.city,
         st_distance(c.location, st_point(lng, lat)::geography) as distance_m,
         st_y(c.location::geometry) as lat, st_x(c.location::geometry) as lng
  from churches c
  where c.location is not null
    and st_dwithin(c.location, st_point(lng, lat)::geography, radius_m)
  order by distance_m limit 50;
$$;

-- Area stats for the map sheet ("12 Evangelists · 5 Outreaches Today · 3 Churches Nearby").
create or replace function area_stats(lat double precision, lng double precision, radius_m int default 5000)
returns table (evangelists int, outreaches_today int, churches_nearby int)
language sql security definer set search_path = public stable as $$
  select
    (select count(*)::int from live_presence lp join profiles p on p.id=lp.user_id
       where lp.is_evangelizing and lp.expires_at > now() and p.is_visible_on_map
         and st_dwithin(lp.location, st_point(lng,lat)::geography, radius_m)),
    (select count(*)::int from outreach_sessions s
       where s.started_at::date = current_date and s.location is not null
         and st_dwithin(s.location, st_point(lng,lat)::geography, radius_m)),
    (select count(*)::int from churches c
       where c.location is not null
         and st_dwithin(c.location, st_point(lng,lat)::geography, radius_m));
$$;

grant execute on function nearby_evangelists(double precision,double precision,int) to authenticated;
grant execute on function nearby_churches(double precision,double precision,int)   to authenticated;
grant execute on function area_stats(double precision,double precision,int)        to authenticated;
grant execute on function end_session(uuid,int,int,int)                            to authenticated;
