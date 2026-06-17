# 02 · Data Model

The complete, runnable schema lives in [`/supabase/schema.sql`](../supabase/schema.sql). This document explains it: what each table is for, how they relate, and the design decisions behind them.

## Entity-relationship overview

```
auth.users ──1:1── profiles
                      │
   ┌──────────────────┼───────────────────────────────────────────┐
   │                  │                                            │
contacts          outreach_sessions        activity_logs      posts
   │ 1:N                 │ 1:N                  ▲ N:1             │ 1:N
followups            (counts roll up)       (logs reference     ├── post_reactions
                                             contact/session/    ├── comments
churches ◄── activity_logs.church_id          church)           └── events ── event_attendees
                                                                       ▲
live_presence ──1:1── profiles (current live location)                 │ posts.event_id
groups ──N:N── group_members ── profiles
achievements ──N:N── user_achievements ── profiles
verses ──1:N── daily_missions ── profiles
profiles ──1:N── notifications, devices
```

**The key relationship to understand:** `activity_logs` is the atomic source of truth. Every Gospel conversation, salvation, prayer, follow-up, and church connection becomes one row. All impact numbers on the Dashboard and Profile, plus the streak, are derived from (and cached from) this table by a trigger. Sessions and contacts are *context* that logs can point at, not the source of the numbers.

## Tables

### profiles
Extends `auth.users` 1:1 (created automatically by the `handle_new_user` trigger). Holds the public identity (name, username, city, church, ministry, bio, avatar) plus settings (`is_visible_on_map`, `daily_reminder_enabled`, `theme`) and **denormalised gamification stats** (`current_streak`, `longest_streak`, `last_evangelism_date`, `weekly_goal`, and the four lifetime totals). The stats are caches kept correct by the `apply_activity_stats` trigger so the Dashboard reads one row instead of aggregating thousands of logs on every open.

### contacts ("My People")
The lightweight evangelism CRM. Owned by one user (`owner_id`). Carries `status` (`spiritual_status` enum), the meeting context (`met_location`, `date_met`), free-form `notes`, `tags[]`, and `next_followup_at`. Indexed by owner, status, and due date so the People list and Dashboard reminders are fast.

### followups
Scheduled touchpoints tied to a contact (Day 1 / 3 / 7 / 14 / 30, or custom via `day_offset`). `status` moves `scheduled → sent → replied/skipped`. `message` is the AI-drafted or user-edited body. A partial index on `(owner_id, scheduled_for) where status='scheduled'` makes the daily cron job that finds "due today" follow-ups cheap.

### outreach_sessions
A timed "I'm out evangelising now" period. Stores start/end, `duration_seconds`, a PostGIS `location` + `location_name`, running counters (`conversations_count`, `prayers_count`, `people_added_count`), and `status` (`live`/`completed`/`cancelled`). Ending a session writes the counters and creates the corresponding `activity_logs` rows.

### activity_logs
The atomic ledger. `type` is the `activity_type` enum. Optional links to `contact_id`, `session_id`, and `church_id` give context. `location` (PostGIS) lets us map where outreach happened. This table is **append-only** — never updated or deleted in normal use — which keeps stats trustworthy and sync conflict-free.

### churches
The church directory new believers connect to. PostGIS `location` (GiST index) powers "churches nearby." `claimed_by` + `is_verified` support the future paid church-profile feature.

### events + event_attendees
Outreach events that appear in the feed with a **Join Outreach** button. `event_attendees` is a join table (composite PK). Outreach posts can reference an event via `posts.event_id`.

### posts / post_reactions / comments
The community feed.
- **posts** — `type` (`post_type` enum: testimony, outreach, prayer, salvation, update), `body`, optional `photo_url`, `city`, `event_id`, and PostGIS `location` (enables the **Nearby** feed). `is_public` gates visibility.
- **post_reactions** — mission-specific reactions only (`encouraged`, `inspired`, `praying`, `amen`); **no generic likes**. Composite PK `(post_id, user_id, reaction)` lets a user add multiple distinct reactions but never duplicate one. Counts come from the `post_reaction_counts` view.
- **comments** — threaded under a post.

### live_presence
The geo-queryable backing store for the live map. One row per currently-live user with PostGIS `location`, `is_evangelizing`, the originating `session_id`, and an `expires_at` (default +5 min) so stale pins disappear. Realtime **Presence** drives instant pin animation; this table answers the `nearby_evangelists()` geo query and survives reconnects. A cron job sweeps expired rows.

### groups / group_members
Ministries/teams shown on profiles ("Atlanta Street Team", "Campus Outreach"). N:N via `group_members` with a `role` (member/leader).

### achievements / user_achievements
A catalog of unlockable badges (seeded in `schema.sql`) and per-user unlocks. Awarding is done by the `award-achievements` logic described in `04-backend-logic.md`.

### verses / daily_missions
`verses` is the Daily Encouragement catalog (seeded). `daily_missions` stores each user's mission for a date as a `tasks` JSONB array (`[{label, done}]`) plus a `verse_id`. One row per user per day (composite PK).

### notifications / devices
`notifications` is the in-app notification feed (`type`, `title`, `body`, `data` JSONB, `read`). `devices` stores FCM push tokens per platform for fan-out from the `send-push` Edge Function.

## Enums

| Enum | Values |
|------|--------|
| `spiritual_status` | new_contact, accepted_christ, followup_started, connected_to_church, active |
| `activity_type` | conversation, salvation, prayer, followup, church_connection |
| `post_type` | testimony, outreach, prayer, salvation, update |
| `reaction_type` | encouraged, inspired, praying, amen |
| `followup_status` | scheduled, sent, replied, skipped |
| `session_status` | live, completed, cancelled |

## Indexing summary

- **Geo (GiST):** `churches.location`, `events.location`, `posts.location`, `live_presence.location` — all `nearby` queries use `ST_DWithin`.
- **Hot lists:** `contacts(owner_id, next_followup_at)`, `followups(owner_id, scheduled_for) where scheduled`, `activity_logs(user_id, occurred_at desc)`, `posts(created_at desc)` and `posts(type, created_at desc)`.
- **Presence sweep:** `live_presence(expires_at)`.

## Design decisions

- **Cached stats + trigger** instead of live aggregation — O(1) dashboard reads; the trigger is the only writer of those columns.
- **Append-only activity ledger** — trustworthy metrics, trivial offline sync (client-generated UUIDs, no merge conflicts).
- **PostGIS over lat/lng floats** — proper radius queries and indexes for the live map; lets us fuzz output in one place.
- **Reactions modelled as rows, not counters** — accurate, abuse-resistant, and lets us show *who* reacted; counts via a view.
- **Presence split** — ephemeral Realtime Presence for instant pins, durable `live_presence` table for geo queries and reconnect safety.
