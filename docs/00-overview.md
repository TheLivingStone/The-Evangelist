# 00 · Overview

## What we are building

The Evangelist is a cross-platform mobile app (iOS + Android) that makes personal evangelism **visible, consistent, and sustainable**. It blends four product instincts:

- **Strava** — track real-world effort: sessions, streaks, impact stats, a live map of who is out evangelising right now.
- **Duolingo** — habit and encouragement: daily goals, streaks, missions, celebratory moments.
- **Notion** — calm, clean, well-organised interface.
- **Twitter/X** — a lightweight, mission-focused community feed.

The single most important action in the app is the centre **➕ Start** ("movement") button, which opens a *What happened today?* sheet: Start Outreach Session, Add Person, Log Conversation, Log Prayer, Create Testimony Post.

## Primary navigation (matches the prototype)

1. **Dashboard** — streak, weekly mission, monthly impact, follow-up reminders, daily encouragement entry.
2. **Community** — Twitter-style evangelism feed with a **Nearby** tab that shows a live map of people evangelising.
3. **➕ Start** — the movement button (bottom sheet of quick actions; "My People" / contacts live here).
4. **Map** — full-screen live map of active evangelists, outreach events, and nearby churches.
5. **Profile** — impact stats, achievements, longest streak, settings (incl. dark/light theme).

## Goals & non-goals

**Goals**
- Increase the North-Star metric: **Active Evangelists** (a user who has shared the Gospel in the last 7 days).
- Make logging an outreach take seconds.
- Keep new believers from falling through the cracks via automated follow-up.
- Encourage without competition (reactions, not leaderboards).

**Non-goals (by design)**
- Not a Bible/devotional app, not a church-management platform, not a generic social network.
- No public rankings or "top evangelist" leaderboards.

## Technology stack

| Layer | Choice | Notes |
|-------|--------|-------|
| Mobile app | **Flutter (Dart)** | One codebase → iOS + Android. (React Native is acceptable if the dev already knows JS/React.) |
| Backend platform | **Supabase** | Managed Postgres + Auth + Realtime + Storage + Edge Functions |
| Database | **Postgres 15+** with **PostGIS** | Relational schema; PostGIS powers the live "nearby evangelists" map |
| Auth | **Supabase Auth** | Email/password, Google, Apple (required for iOS) |
| Realtime | **Supabase Realtime** | Live map presence, live community feed updates |
| Files | **Supabase Storage** | Contact selfies, profile photos, outreach photos |
| Server logic | **Edge Functions (Deno/TypeScript)** + **Postgres functions/triggers** + **pg_cron** | Follow-up sequences, AI generation, push fan-out |
| Push | **Firebase Cloud Messaging (FCM)** | Supabase has no native push; FCM delivers to both platforms |
| AI | **Claude or OpenAI API** (server-side) | Follow-up message drafts, daily encouragement |
| Maps | **Google Maps SDK** (`google_maps_flutter`) | Map rendering on device; PostGIS does the geo queries |

> Why Supabase over Firebase here: you chose Postgres for a real relational schema, SQL you fully control, row-level security, and portability. The trade-off is that presence/geo and push need a little more wiring, which these docs spell out.

## Glossary

- **Outreach session** — a timed "I'm out evangelising now" period; produces activity logs and (optionally) live-map presence.
- **Activity log** — an atomic record of a Gospel conversation, salvation, prayer, follow-up, or church connection. The source of truth for all impact stats and streaks.
- **Contact** — someone the user met and is following up with (the lightweight CRM, surfaced as "My People").
- **Follow-up** — a scheduled touchpoint (Day 1/3/7/14/30) tied to a contact.
- **Post** — a community item: testimony, outreach update, prayer request, salvation story, or update.
- **Reaction** — `encouraged`, `inspired`, `praying`, or `amen` (no generic "likes").
- **Presence** — a user's current live location + evangelising status, shown on the map.

## How the documents fit together

`02-data-model` defines the tables. `03-security-rls` locks them down. `04-backend-logic` adds the moving parts (functions, cron, realtime, AI, push). `05-feature-specs` maps each screen to the data and actions it needs. Start at whichever layer you are implementing; everything cross-references by table and function name.
