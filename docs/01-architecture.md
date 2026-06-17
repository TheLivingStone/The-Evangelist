# 01 · Architecture

## System overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter app (iOS + Android)                │
│                                                               │
│  UI layer (screens)  →  Repositories  →  supabase_flutter SDK │
│  google_maps_flutter      (Dart)            (Postgrest/Realtime/Auth/Storage)
│  local cache (Isar/Drift) for offline                          │
└───────────────┬───────────────────────────────────────────────┘
                │ HTTPS / WebSocket (JWT auth)
                ▼
┌─────────────────────────────────────────────────────────────┐
│                         SUPABASE                              │
│                                                               │
│  Auth (GoTrue) ── issues JWT, social login (Google/Apple)     │
│                                                               │
│  Postgres 15 + PostGIS                                        │
│    • Tables (data-model)                                      │
│    • Row-Level Security (security-rls)                        │
│    • Functions / triggers (stats, streaks, nearby query)      │
│    • pg_cron (follow-up sequences, daily missions)            │
│                                                               │
│  Realtime ── presence channel (live map), feed changes        │
│  Storage  ── avatars, selfies, outreach photos                │
│  Edge Functions (Deno/TS)                                     │
│    • ai-generate (follow-up + encouragement)                  │
│    • send-push (FCM fan-out)                                  │
│    • process-followups (called by cron)                       │
└───────────────┬───────────────────────────────────────────────┘
                │ outbound HTTPS
                ▼
   Claude/OpenAI API   ·   Firebase Cloud Messaging   ·   Google Maps
```

## Client architecture (Flutter)

Use a simple, layered structure that a solo developer can keep clean:

- **Presentation** — screens + widgets (one folder per feature: `dashboard/`, `community/`, `sessions/`, `people/`, `map/`, `profile/`).
- **State** — Riverpod (recommended) or Bloc. One provider/controller per feature.
- **Domain** — plain Dart models mirroring the DB tables (`Profile`, `Contact`, `OutreachSession`, `ActivityLog`, `Post`, ...).
- **Data (repositories)** — the only layer that talks to Supabase. Each repository wraps Postgrest queries, Realtime subscriptions, and Storage calls. This keeps SQL/queries out of the UI and makes testing easy.
- **Local cache** — Drift or Isar for offline reads and an outbox queue for writes made while offline.

```
lib/
  main.dart
  core/            # supabase client, theme, router, env, error handling
  models/          # Profile, Contact, ActivityLog, OutreachSession, Post, ...
  repositories/    # profile_repo, contacts_repo, sessions_repo, feed_repo, map_repo
  features/
    dashboard/
    community/
    sessions/
    people/
    map/
    profile/
    encouragement/
  widgets/         # shared UI (StreakCard, StatGrid, PostCard, LivePin, ...)
```

## Data flow examples

**Logging an outreach (Start → Log Conversation)**
1. UI calls `activitiesRepo.log(type: conversation, sessionId, location)`.
2. Repo inserts a row into `activity_logs`.
3. A Postgres trigger updates the user's cached stats and recomputes the streak.
4. Realtime pushes the new activity to the user's own Dashboard; a celebratory sheet shows in the UI.

**Live map (Community → Nearby / Map tab)**
1. While a session is live, the app updates the Supabase **Realtime Presence** channel `evangelists` every ~15s with `{user_id, lat, lng, is_evangelizing}` and upserts a row in `live_presence`.
2. The map screen calls the RPC `nearby_evangelists(lat, lng, radius_m)` which returns **fuzzed** locations of visible, currently-live evangelists (PostGIS `ST_DWithin`).
3. Realtime presence events animate pins in/out instantly between RPC refreshes.

**Community post + reaction**
1. Composer inserts into `posts`.
2. Feed screens subscribe to Realtime on `posts` (and `post_reactions`) so new posts/reactions appear live.
3. Reaction counts are read from a view/aggregate; tapping a reaction upserts `post_reactions`.

## Realtime strategy

| Need | Mechanism |
|------|-----------|
| Live map of evangelists | Realtime **Presence** (ephemeral) + `live_presence` table for geo queries |
| Live community feed | Realtime **Postgres Changes** on `posts`, `post_reactions`, `comments` |
| Own dashboard updates | Realtime on `activity_logs` filtered to `user_id = me` |
| Follow-up reminders | Push (FCM) + a badge query on app open |

## Offline & sync

- **Reads:** cache the user's own contacts, follow-ups, recent activity, and dashboard stats in Drift/Isar; render from cache first, then refresh.
- **Writes:** queue writes (log activity, add contact, end session) in a local **outbox**; flush when connectivity returns. Use client-generated UUIDs so offline rows keep stable IDs.
- **Conflict policy:** activity logs and sessions are append-only (no conflicts). Profile/contact edits use last-write-wins on `updated_at`.

## Environments

| Env | Supabase project | Use |
|-----|------------------|-----|
| `dev` | evangelist-dev | Local development, seed data |
| `staging` | evangelist-staging | TestFlight / Play internal testing |
| `prod` | evangelist-prod | Live users |

Store the Supabase URL + anon key per environment via Dart `--dart-define` (never hard-code secrets). Service-role keys live **only** in Edge Functions / server config, never in the app.

## Security posture (summary)

- Every table has **RLS enabled**; the anon/auth client can only ever see what policies allow (see `03-security-rls.md`).
- The app uses the **anon key + user JWT** only. Privileged work (push fan-out, AI calls, cron) runs in Edge Functions with the **service-role key**.
- The live map never exposes exact coordinates to other users — the `nearby_evangelists` RPC returns rounded/fuzzed positions and respects each user's `is_visible_on_map` flag.
