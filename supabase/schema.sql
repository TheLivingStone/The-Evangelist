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
