-- =====================================================================
-- The Evangelist — COMPLETE one-paste database setup.
-- Copy this ENTIRE file, paste into the Supabase SQL Editor, click Run.
-- Order: core (reset+schema+policies) -> church members -> church
-- registration -> feed comments/photos -> admin analytics.
-- Safe to re-run. Requires postgis + pg_cron (already enabled).
-- =====================================================================


-- ##################################################################
-- ##  PART 1 of 5 — CORE (reset + schema + policies)              ##
-- ##################################################################
-- =====================================================================
-- The Evangelist — ONE-SHOT database setup (Supabase Auth model).
-- Paste this ENTIRE file into the Supabase SQL Editor and Run once.
-- It runs: reset (drop old) -> schema (create) -> policies (RLS+RPCs).
-- Re-runnable: safe to run again from any half-set-up state.
--
-- AUTH MODEL: Supabase Auth. profiles.id is a uuid referencing
-- auth.users(id); the current user is auth.uid(). A handle_new_user()
-- trigger creates the profiles row automatically on signup.
--
-- After this, run the feature migrations (any order, all idempotent):
--   migrate_church_members.sql, migrate_church_registration.sql,
--   migrate_feed_comments_photos.sql, migrate_admin_analytics.sql
-- =====================================================================

-- ########## 1/3 RESET ##########
-- =====================================================================
-- The Evangelist — DESTRUCTIVE reset (run FIRST, before schema.sql).
--
-- Drops every object the app owns so schema.sql + policies.sql can recreate
-- them cleanly. Use this to rebuild the database from scratch on the current
-- Supabase Auth model (profiles.id as uuid referencing auth.users, auth.uid()).
--
-- ⚠️  This DELETES ALL DATA in these tables. Safe here because the project has
--     no real users yet — only the achievement/verse seeds, which schema.sql
--     re-inserts. Do NOT run this against a database with real user data.
--
-- Run order:  reset.sql  →  schema.sql  →  policies.sql
-- =====================================================================

-- ---------- Auth trigger (recreated by schema.sql) ----------
-- Drop so schema.sql can recreate them cleanly.
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
--
-- AUTH MODEL: Supabase Auth. The current user is auth.uid() (a uuid).
-- profiles.id IS that uuid and references auth.users(id) ON DELETE CASCADE,
-- so deleting the auth user (account deletion) removes all of their data.
-- A handle_new_user() trigger creates the profiles row automatically on
-- signup (including anonymous "guest" signups), reading full_name from the
-- user's raw_user_meta_data.
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
-- PROFILES  (1:1 with a Supabase Auth user)
-- id = auth.users(id). The handle_new_user() trigger (below) inserts this
-- row on signup, so the app never has to create it. ON DELETE CASCADE means
-- removing the auth user wipes the profile and everything that references it.
-- =====================================================================
create table profiles (
  id                       uuid primary key references auth.users(id) on delete cascade,
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
comment on table profiles is 'Public-facing user profile; id = auth.users id (uuid). Stats are denormalised caches maintained by triggers.';

-- =====================================================================
-- CONTACTS  ("My People" — the evangelism CRM)
-- =====================================================================
create table contacts (
  id               uuid primary key default gen_random_uuid(),
  owner_id         uuid not null references profiles(id) on delete cascade,
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
  owner_id     uuid not null references profiles(id) on delete cascade,
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
  user_id           uuid not null references profiles(id) on delete cascade,
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
  user_id     uuid not null references profiles(id) on delete cascade,
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
  claimed_by         uuid references profiles(id) on delete set null,
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
  host_id       uuid not null references profiles(id) on delete cascade,
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
  user_id   uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- =====================================================================
-- COMMUNITY: POSTS, REACTIONS, COMMENTS
-- =====================================================================
create table posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references profiles(id) on delete cascade,
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
  user_id    uuid not null references profiles(id) on delete cascade,
  reaction   reaction_type not null,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id, reaction)
);
create index idx_reactions_post on post_reactions(post_id);

create table comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
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
  user_id         uuid primary key references profiles(id) on delete cascade,
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
  created_by  uuid references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create table group_members (
  group_id  uuid not null references groups(id) on delete cascade,
  user_id   uuid not null references profiles(id) on delete cascade,
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
  user_id        uuid not null references profiles(id) on delete cascade,
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
  user_id    uuid not null references profiles(id) on delete cascade,
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
  user_id    uuid not null references profiles(id) on delete cascade,
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
  user_id    uuid not null references profiles(id) on delete cascade,
  fcm_token  text not null unique,
  platform   text not null,                            -- 'ios' | 'android'
  created_at timestamptz not null default now()
);

-- =====================================================================
-- TRIGGERS & FUNCTIONS
-- =====================================================================

-- Create a profiles row automatically whenever a Supabase Auth user is
-- created (email/password, OAuth, OR anonymous guest). full_name is read
-- from the signup metadata; it falls back to 'Evangelist' so the NOT NULL
-- column is always satisfied (anonymous users seed 'Guest' from the client).
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 'Evangelist')
  )
  on conflict (id) do nothing;
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

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
  v_user_id uuid;
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
    and user_id = auth.uid()
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
-- Model: identity is provided by SUPABASE AUTH. The app sends the anon
-- (publishable) key + the Supabase session JWT. The current user's id is
-- a uuid read with  auth.uid()  and equals profiles.id.
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
-- The handle_new_user() trigger creates the profiles row on signup, so the app
-- normally never inserts. This policy still allows a self-insert (id = auth.uid())
-- as a safety net for the upsert path.
create policy "users insert their own profile"
  on profiles for insert to authenticated with check (id = auth.uid());
create policy "users update their own profile"
  on profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------- CONTACTS (owner-only, fully private) ----------
create policy "owner can read contacts"   on contacts for select to authenticated using (owner_id = auth.uid());
create policy "owner can insert contacts" on contacts for insert to authenticated with check (owner_id = auth.uid());
create policy "owner can update contacts" on contacts for update to authenticated using (owner_id = auth.uid());
create policy "owner can delete contacts" on contacts for delete to authenticated using (owner_id = auth.uid());

-- ---------- FOLLOWUPS (owner-only) ----------
create policy "owner rw followups"
  on followups for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- ---------- OUTREACH SESSIONS (owner-only) ----------
create policy "owner rw sessions"
  on outreach_sessions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- ACTIVITY LOGS (owner can insert/read own; append-only) ----------
create policy "owner read logs"   on activity_logs for select to authenticated using (user_id = auth.uid());
create policy "owner insert logs" on activity_logs for insert to authenticated with check (user_id = auth.uid());
-- (no update/delete policies => append-only for clients)

-- ---------- CHURCHES (public read; authed create; claimant edits) ----------
create policy "churches public read" on churches for select to authenticated using (true);
create policy "authed add church"    on churches for insert to authenticated with check (auth.uid() is not null);
create policy "claimant edits church" on churches for update to authenticated using (claimed_by = auth.uid());

-- ---------- EVENTS (public read; host manages) ----------
create policy "events public read" on events for select to authenticated using (true);
create policy "host manages events" on events for all to authenticated
  using (host_id = auth.uid()) with check (host_id = auth.uid());

create policy "attendees readable" on event_attendees for select to authenticated using (true);
create policy "join/leave own"     on event_attendees for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- POSTS (public read; author writes) ----------
create policy "public posts readable" on posts for select to authenticated using (is_public = true or author_id = auth.uid());
create policy "author creates post"   on posts for insert to authenticated with check (author_id = auth.uid());
create policy "author edits post"     on posts for update to authenticated using (author_id = auth.uid());
create policy "author deletes post"   on posts for delete to authenticated using (author_id = auth.uid());

-- ---------- REACTIONS & COMMENTS (public read; own writes) ----------
create policy "reactions readable" on post_reactions for select to authenticated using (true);
create policy "own reactions"      on post_reactions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "comments readable" on comments for select to authenticated using (true);
create policy "author writes comment" on comments for insert to authenticated with check (author_id = auth.uid());
create policy "author edits comment"  on comments for update to authenticated using (author_id = auth.uid());
create policy "author deletes comment" on comments for delete to authenticated using (author_id = auth.uid());

-- ---------- LIVE PRESENCE (write own only; NO direct select) ----------
-- Clients never SELECT this table directly. They get fuzzed locations via
-- the nearby_evangelists() RPC, which respects is_visible_on_map.
create policy "upsert own presence" on live_presence for insert to authenticated with check (user_id = auth.uid());
create policy "update own presence" on live_presence for update to authenticated using (user_id = auth.uid());
create policy "delete own presence" on live_presence for delete to authenticated using (user_id = auth.uid());
-- (deliberately no SELECT policy)

-- ---------- GROUPS ----------
create policy "groups public read" on groups for select to authenticated using (true);
create policy "creator manages group" on groups for all to authenticated
  using (created_by = auth.uid()) with check (created_by = auth.uid());
create policy "members readable" on group_members for select to authenticated using (true);
create policy "join/leave groups" on group_members for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- ACHIEVEMENTS ----------
create policy "achievement catalog readable" on achievements for select to authenticated using (true);
create policy "verse catalog readable"       on verses for select to authenticated using (true);
create policy "own achievements readable"    on user_achievements for select to authenticated using (user_id = auth.uid());
-- user_achievements are written by service-role (award logic), not clients.

-- ---------- DAILY MISSIONS (owner-only) ----------
create policy "owner rw missions" on daily_missions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------- NOTIFICATIONS (owner read/update; created by service role) ----------
create policy "owner reads notifications"   on notifications for select to authenticated using (user_id = auth.uid());
create policy "owner updates notifications" on notifications for update to authenticated using (user_id = auth.uid());

-- ---------- DEVICES (owner-only) ----------
create policy "owner rw devices" on devices for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- =====================================================================
-- PRIVACY-PRESERVING RPCs (security definer = run as owner, bypass RLS,
-- but only return what we explicitly allow).
-- =====================================================================

-- Nearby evangelists for the live map. Returns FUZZED locations only,
-- for users who are currently live, not expired, and map-visible.
create or replace function nearby_evangelists(lat double precision, lng double precision, radius_m int default 5000)
returns table (
  user_id uuid, full_name text, avatar_url text,
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
    and p.id <> auth.uid()
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


-- ##################################################################
-- ##  PART 2 of 5 — CHURCH MEMBERS                               ##
-- ##################################################################
-- =====================================================================
-- The Evangelist — Church membership (members ↔ churches)
-- Built 2026-06-20, corrected for Supabase Auth 2026-06-21. Idempotent
-- (safe to re-run). Run AFTER schema.sql + policies.sql +
-- migrate_church_registration.sql.
--
-- AUTH MODEL: Supabase Auth. User ids are uuid; the current user is auth.uid()
-- (NOT auth.jwt()->>'sub'). Every column referencing profiles(id) is uuid.
--
-- WHY: link evangelists to a REAL directory church (not the free-text
-- profiles.church). Once linked, every salvation/conversation/prayer a member
-- logs rolls up to their church → a "church fruitfulness" signal: churches whose
-- people actively evangelize and see salvations are healthy, fruitful churches.
--
-- MODEL:
--   • A member picks their church from the directory  → join_church()
--       creates a PENDING membership.
--   • The church's claimant confirms or removes them  → confirm_member()/remove_member()
--   • ONE home church per member (unique on member_id where status<>'removed').
-- =====================================================================

-- ---------- 1. church_members table ----------
-- Drop any stale/partial version first: an earlier run created this table with
-- member_id typed as text, which is incompatible with profiles.id (uuid). No
-- real data exists yet, so dropping is safe and makes this self-healing.
drop table if exists church_members cascade;
create table church_members (
  id          uuid primary key default gen_random_uuid(),
  church_id   uuid not null references churches(id) on delete cascade,
  member_id   uuid not null references profiles(id) on delete cascade,
  status      text not null default 'pending',   -- pending | confirmed | removed
  role        text,                              -- optional: 'member','leader','volunteer'
  requested_at timestamptz not null default now(),
  confirmed_at timestamptz,
  confirmed_by uuid references profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

alter table church_members drop constraint if exists church_members_status_chk;
alter table church_members add constraint church_members_status_chk
  check (status in ('pending','confirmed','removed'));

-- One active (non-removed) home church per member.
create unique index if not exists uq_church_members_one_home
  on church_members (member_id) where status <> 'removed';

create index if not exists idx_church_members_church on church_members (church_id, status);
create index if not exists idx_church_members_member on church_members (member_id);

-- Convenience FK on profiles so we can read a member's confirmed church directly.
alter table profiles add column if not exists church_id uuid references churches(id) on delete set null;
create index if not exists idx_profiles_church_id on profiles (church_id);

-- ---------- 2. RLS ----------
alter table church_members enable row level security;

-- A member can see their own membership rows.
drop policy if exists cm_member_read on church_members;
create policy cm_member_read on church_members
  for select to authenticated
  using (member_id = auth.uid());

-- A church claimant can see the membership rows for churches they manage.
drop policy if exists cm_claimant_read on church_members;
create policy cm_claimant_read on church_members
  for select to authenticated
  using (exists (
    select 1 from churches c
    where c.id = church_members.church_id
      and c.claimed_by = auth.uid()
  ));

-- All writes go through the SECURITY DEFINER RPCs below (no direct client write).

-- ---------- 3. join_church: member attaches to a directory church ----------
create or replace function join_church(p_church_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from churches where id = p_church_id) then
    raise exception 'Church not found';
  end if;

  -- Drop any existing non-removed membership (one home church).
  update church_members
     set status = 'removed'
   where member_id = v_uid and status <> 'removed' and church_id <> p_church_id;

  -- Re-activate an existing row for this church, else insert a fresh one.
  update church_members
     set status = 'pending', requested_at = now(), confirmed_at = null, confirmed_by = null
   where member_id = v_uid and church_id = p_church_id
   returning id into v_id;

  if v_id is null then
    insert into church_members (church_id, member_id, status)
    values (p_church_id, v_uid, 'pending')
    returning id into v_id;
  end if;

  return v_id;
end; $$;

-- ---------- 4. leave_church: member detaches ----------
create or replace function leave_church()
returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;
  update church_members set status = 'removed'
    where member_id = v_uid and status <> 'removed';
  update profiles set church_id = null where id = v_uid;
end; $$;

-- ---------- 5. confirm_member: church claimant approves a pending member ----
create or replace function confirm_member(p_membership_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_church uuid;
  v_member uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select cm.church_id, cm.member_id into v_church, v_member
  from church_members cm where cm.id = p_membership_id;
  if not found then raise exception 'Membership not found'; end if;

  if not exists (
    select 1 from churches c where c.id = v_church and c.claimed_by = v_uid
  ) then
    raise exception 'Only the church manager can confirm members';
  end if;

  update church_members
     set status = 'confirmed', confirmed_at = now(), confirmed_by = v_uid
   where id = p_membership_id;

  update profiles set church_id = v_church where id = v_member;
end; $$;

-- ---------- 6. remove_member: church claimant removes a member ------------
create or replace function remove_member(p_membership_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_church uuid;
  v_member uuid;
begin
  if v_uid is null then raise exception 'Not authenticated'; end if;

  select cm.church_id, cm.member_id into v_church, v_member
  from church_members cm where cm.id = p_membership_id;
  if not found then raise exception 'Membership not found'; end if;

  if not exists (
    select 1 from churches c where c.id = v_church and c.claimed_by = v_uid
  ) then
    raise exception 'Only the church manager can remove members';
  end if;

  update church_members set status = 'removed' where id = p_membership_id;
  update profiles set church_id = null
    where id = v_member and church_id = v_church;
end; $$;

-- ---------- 7. my_church_membership: what church am I in? ----------
create or replace function my_church_membership()
returns table (
  membership_id uuid, church_id uuid, church_name text, city text,
  is_verified boolean, status text, requested_at timestamptz, confirmed_at timestamptz
)
language sql security definer set search_path = public stable as $$
  select cm.id, c.id, c.name, c.city, c.is_verified,
         cm.status, cm.requested_at, cm.confirmed_at
  from church_members cm
  join churches c on c.id = cm.church_id
  where cm.member_id = auth.uid() and cm.status <> 'removed'
  order by cm.requested_at desc
  limit 1;
$$;

-- ---------- 8. church_member_requests: pending members for MY church ----------
create or replace function church_member_requests(p_church_id uuid)
returns table (
  membership_id uuid, member_id uuid, full_name text, username text,
  city text, avatar_url text, status text, requested_at timestamptz,
  total_salvations int, total_conversations int
)
language sql security definer set search_path = public stable as $$
  select cm.id, p.id, p.full_name, p.username, p.city, p.avatar_url,
         cm.status, cm.requested_at, p.total_salvations, p.total_conversations
  from church_members cm
  join profiles p on p.id = cm.member_id
  join churches c on c.id = cm.church_id
  where cm.church_id = p_church_id
    and c.claimed_by = auth.uid()   -- only the manager sees this
    and cm.status <> 'removed'
  order by (cm.status = 'pending') desc, cm.requested_at desc;
$$;

grant execute on function join_church(uuid) to authenticated;
grant execute on function leave_church() to authenticated;
grant execute on function confirm_member(uuid) to authenticated;
grant execute on function remove_member(uuid) to authenticated;
grant execute on function my_church_membership() to authenticated;
grant execute on function church_member_requests(uuid) to authenticated;

-- =====================================================================
-- 9. ADMIN: Church fruitfulness (service-role only) — the whole point.
--    Ranks churches by the evangelism their members actually do.
-- =====================================================================

create or replace function admin_church_fruitfulness(p_days int default null, p_limit int default 100)
returns table (
  church_id uuid,
  name text,
  city text,
  is_verified boolean,
  members int,
  active_members int,
  salvations int,
  conversations int,
  prayers int,
  followups int,
  fruitfulness numeric
)
language sql security definer set search_path = public stable as $$
  with mem as (
    select cm.church_id, cm.member_id
    from church_members cm
    where cm.status = 'confirmed'
  ),
  acts as (
    select m.church_id, a.type, a.user_id, a.occurred_at
    from mem m
    join activity_logs a on a.user_id = m.member_id
    where p_days is null or a.occurred_at >= (current_date - (p_days - 1))
  ),
  agg as (
    select
      m.church_id,
      count(distinct m.member_id)::int as members,
      count(distinct a.user_id) filter (where a.user_id is not null)::int as active_members,
      count(a.*) filter (where a.type = 'salvation')::int as salvations,
      count(a.*) filter (where a.type = 'conversation')::int as conversations,
      count(a.*) filter (where a.type = 'prayer')::int as prayers,
      count(a.*) filter (where a.type = 'followup')::int as followups
    from mem m
    left join acts a on a.church_id = m.church_id and a.user_id = m.member_id
    group by m.church_id
  )
  select
    c.id, c.name, c.city, c.is_verified,
    coalesce(g.members,0), coalesce(g.active_members,0),
    coalesce(g.salvations,0), coalesce(g.conversations,0),
    coalesce(g.prayers,0), coalesce(g.followups,0),
    (coalesce(g.salvations,0) * 5
     + coalesce(g.conversations,0) * 2
     + coalesce(g.prayers,0)
     + coalesce(g.followups,0))::numeric as fruitfulness
  from churches c
  join agg g on g.church_id = c.id
  order by fruitfulness desc, coalesce(g.salvations,0) desc
  limit p_limit;
$$;

create or replace function admin_church_members(p_church_id uuid)
returns table (
  membership_id uuid, member_id uuid, full_name text, username text,
  city text, status text, requested_at timestamptz, confirmed_at timestamptz,
  total_salvations int, total_conversations int, current_streak int
)
language sql security definer set search_path = public stable as $$
  select cm.id, p.id, p.full_name, p.username, p.city,
         cm.status, cm.requested_at, cm.confirmed_at,
         p.total_salvations, p.total_conversations, p.current_streak
  from church_members cm
  join profiles p on p.id = cm.member_id
  where cm.church_id = p_church_id and cm.status <> 'removed'
  order by (cm.status = 'pending') desc, p.total_salvations desc;
$$;

create or replace function admin_membership_stats()
returns table (
  churches_with_members int,
  confirmed_members int,
  pending_members int,
  members_evangelizing int
)
language sql security definer set search_path = public stable as $$
  select
    (select count(distinct church_id) from church_members where status = 'confirmed')::int,
    (select count(*) from church_members where status = 'confirmed')::int,
    (select count(*) from church_members where status = 'pending')::int,
    (select count(distinct cm.member_id)
       from church_members cm
       join activity_logs a on a.user_id = cm.member_id
      where cm.status = 'confirmed')::int;
$$;

-- Admin grants: these admin_* functions are service-role only.
do $$
declare fn text;
begin
  for fn in
    select format('%I(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_church_fruitfulness','admin_church_members','admin_membership_stats')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end $$;


-- ##################################################################
-- ##  PART 3 of 5 — CHURCH REGISTRATION                          ##
-- ##################################################################
-- =====================================================================
-- The Evangelist — Church registration & vetting
-- Idempotent. Run AFTER schema.sql + policies.sql (safe to re-run).
--
-- Model: ANYONE can register/claim a church, but it is NOT trusted until an
-- owner verifies it (after a real meeting to confirm the pastor/church). So:
--   • register_church  → inserts a church, located at the caller's GPS point,
--                        claimed by the caller, is_verified=false,
--                        claim_status='pending'.
--   • claim_church     → a pastor claims an EXISTING directory church; records
--                        their claim and flips it back to pending for review.
-- Verification happens only in the admin dashboard.
-- =====================================================================

-- ---------- 1. Claim / vetting columns ----------
alter table churches add column if not exists claimant_name  text;
alter table churches add column if not exists claimant_role  text;   -- 'Lead Pastor', 'Elder', ...
alter table churches add column if not exists claimant_phone text;
alter table churches add column if not exists claimant_email text;
alter table churches add column if not exists claim_status   text not null default 'unclaimed';
alter table churches add column if not exists claim_notes    text;    -- internal notes from the vetting meeting
alter table churches add column if not exists claimed_at     timestamptz;

-- Constrain claim_status to known values (drop-then-add = re-runnable).
alter table churches drop constraint if exists churches_claim_status_chk;
alter table churches add constraint churches_claim_status_chk
  check (claim_status in ('unclaimed','pending','approved','rejected'));

create index if not exists idx_churches_claim_status on churches(claim_status);

-- ---------- 2. register_church RPC ----------
-- Creates a new directory entry located at the given GPS point, claimed by the
-- caller, pending review. Returns the new church id.
create or replace function register_church(
  p_name          text,
  p_lat           double precision,
  p_lng           double precision,
  p_address       text default null,
  p_city          text default null,
  p_service_times text default null,
  p_website       text default null,
  p_statement     text default null,
  p_claimant_name  text default null,
  p_claimant_role  text default null,
  p_claimant_phone text default null,
  p_claimant_email text default null
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_id  uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;
  if coalesce(trim(p_name), '') = '' then
    raise exception 'Church name is required';
  end if;

  insert into churches (
    name, location, address, city, service_times, website, statement_of_faith,
    claimed_by, is_verified, claim_status,
    claimant_name, claimant_role, claimant_phone, claimant_email, claimed_at
  ) values (
    p_name,
    case when p_lat is null or p_lng is null
         then null
         else st_point(p_lng, p_lat)::geography end,
    p_address, p_city, p_service_times, p_website, p_statement,
    v_uid, false, 'pending',
    p_claimant_name, p_claimant_role, p_claimant_phone, p_claimant_email, now()
  )
  returning id into v_id;

  return v_id;
end; $$;

-- ---------- 3. claim_church RPC ----------
-- A pastor claims an EXISTING church. Refuses if it is already verified AND
-- claimed by someone else (can't hijack a vetted listing). Otherwise records
-- the claim and sets it pending for owner review.
create or replace function claim_church(
  p_church_id      uuid,
  p_claimant_name  text,
  p_claimant_role  text,
  p_claimant_phone text default null,
  p_claimant_email text default null,
  p_message        text default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_existing_owner uuid;
  v_verified boolean;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select claimed_by, is_verified into v_existing_owner, v_verified
  from churches where id = p_church_id;

  if not found then
    raise exception 'Church not found';
  end if;
  if v_verified and v_existing_owner is not null and v_existing_owner <> v_uid then
    raise exception 'This church is already verified and managed by someone else';
  end if;

  update churches set
    claimed_by     = v_uid,
    claimant_name  = p_claimant_name,
    claimant_role  = p_claimant_role,
    claimant_phone = p_claimant_phone,
    claimant_email = p_claimant_email,
    claim_notes    = p_message,
    claim_status   = 'pending',
    claimed_at     = now()
  where id = p_church_id;
end; $$;

-- ---------- 4. nearby_churches: include verification status ----------
-- Return type changes, so drop the old function first.
drop function if exists nearby_churches(double precision, double precision, int);
create or replace function nearby_churches(
  lat double precision, lng double precision, radius_m int default 8000
)
returns table (
  id uuid, name text, city text, address text, service_times text,
  website text, is_verified boolean, claim_status text,
  distance_m double precision, lat_out double precision, lng_out double precision
)
language sql security definer set search_path = public stable as $$
  select c.id, c.name, c.city, c.address, c.service_times,
         c.website, c.is_verified, c.claim_status,
         st_distance(c.location, st_point(lng, lat)::geography) as distance_m,
         st_y(c.location::geometry) as lat_out,
         st_x(c.location::geometry) as lng_out
  from churches c
  where c.location is not null
    and st_dwithin(c.location, st_point(lng, lat)::geography, radius_m)
  order by distance_m
  limit 50;
$$;

grant execute on function register_church(text,double precision,double precision,text,text,text,text,text,text,text,text,text) to authenticated;
grant execute on function claim_church(uuid,text,text,text,text,text) to authenticated;
grant execute on function nearby_churches(double precision,double precision,int) to authenticated;


-- ##################################################################
-- ##  PART 4 of 5 — FEED COMMENTS + PHOTOS                       ##
-- ##################################################################
-- =====================================================================
-- The Evangelist — Feed upgrade: comment counts + post photos
-- Idempotent. Run AFTER schema.sql + policies.sql (safe to re-run).
-- Adds:
--   1. post_comment_counts  — view powering the "💬 N" indicator on cards
--   2. a public 'post-photos' Storage bucket + RLS so users can attach a
--      photo to a post (public read; owner-scoped writes).
-- The comments TABLE and its RLS already exist (schema.sql / policies.sql);
-- this file only adds the count view and the photo storage plumbing.
-- =====================================================================

-- ---------- 1. Comment counts per post (mirrors post_reaction_counts) ----------
create or replace view post_comment_counts as
  select post_id, count(*)::int as cnt
  from comments
  group by post_id;

-- ---------- 2. Public Storage bucket for post photos ----------
-- Create the bucket if missing. Public so image URLs load like normal CDN
-- links (posts are already public). 5 MB cap, common image mime types only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'post-photos',
  'post-photos',
  true,
  5242880,                                  -- 5 MB
  array['image/jpeg','image/png','image/webp','image/heic']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- RLS on storage.objects: public read for this bucket, owner-scoped writes.
-- Files are stored under "<user_id>/<filename>", so the first path segment
-- must equal the caller's auth.uid() (cast to text) for insert/update/delete.
-- Drop-then-create keeps this migration safely re-runnable.
drop policy if exists "post-photos public read"   on storage.objects;
drop policy if exists "post-photos owner upload"   on storage.objects;
drop policy if exists "post-photos owner update"   on storage.objects;
drop policy if exists "post-photos owner delete"   on storage.objects;

create policy "post-photos public read"
  on storage.objects for select
  using (bucket_id = 'post-photos');

create policy "post-photos owner upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "post-photos owner update"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "post-photos owner delete"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- ##################################################################
-- ##  PART 5 of 5 — ADMIN ANALYTICS                              ##
-- ##################################################################
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
