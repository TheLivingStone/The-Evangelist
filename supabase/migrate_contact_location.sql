-- =====================================================================
-- The Evangelist — Contact met-location
-- Built 2026-07-01. Idempotent (safe to re-run). Run AFTER schema.sql.
--
-- WHY: remember exactly where a contact was met, as a quiet reminder
-- alongside the free-text met_location the user types themselves. "When" a
-- contact was met already has a precise answer (contacts.created_at, set
-- automatically on insert) — this migration only adds what was missing:
-- "where".
--
-- Plain double precision, not PostGIS geography — there's no need to query
-- contacts by proximity (unlike outreach_sessions/live_presence/churches),
-- so a geography column + spatial index would be unused complexity here.
-- Nullable, no default: a contact still saves fine with no location
-- (permission denied, location services off, GPS timeout, etc all just mean
-- these stay null — never blocks saving the person).
-- =====================================================================

alter table contacts add column if not exists met_lat double precision;
alter table contacts add column if not exists met_lng double precision;
