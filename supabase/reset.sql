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
