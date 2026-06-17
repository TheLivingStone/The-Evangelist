-- =====================================================================
-- The Evangelist — Row-Level Security policies + helper RPCs
-- Run this file AFTER schema.sql.
-- Model: the app uses the anon key + a signed-in user's JWT. auth.uid()
-- returns the current user's id. Privileged jobs use the service role,
-- which bypasses RLS.
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
