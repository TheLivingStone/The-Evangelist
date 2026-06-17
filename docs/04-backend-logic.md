# 04 · Backend Logic & APIs

How the moving parts work: the RPCs the app calls, the Edge Functions that run privileged work, the scheduled jobs, realtime, AI, and push. The data API itself (CRUD on tables) is provided automatically by Supabase Postgrest under the RLS rules in `03-security-rls.md`; this document covers everything *beyond* plain CRUD.

## 1. The app's API surface

The Flutter app talks to the backend three ways:

1. **Postgrest (auto REST)** — `supabase.from('table').select()/insert()/update()` for normal data, gated by RLS.
2. **RPC** — `supabase.rpc('fn', params)` for the security-definer functions (geo + stats).
3. **Realtime** — `supabase.channel(...)` for presence and live table changes.

### RPC reference

| Function | Params | Returns | Used by |
|----------|--------|---------|---------|
| `nearby_evangelists(lat,lng,radius_m)` | point + radius | fuzzed live evangelist pins | Map tab, Community → Nearby |
| `nearby_churches(lat,lng,radius_m)` | point + radius | nearby churches | Map, contact → church recommendation |
| `area_stats(lat,lng,radius_m)` | point + radius | `{evangelists, outreaches_today, churches_nearby}` | Map sheet |
| `start_session(lat,lng,name)` *(optional helper)* | start point | new session id | Start Outreach |
| `end_session(session_id, cv, pr, pa)` *(optional helper)* | counters | void; writes logs | End Session |

> `start_session`/`end_session` can also be done as plain inserts/updates from the client; provide them as RPCs if you want the session→logs fan-out to happen atomically server-side.

## 2. Edge Functions (Deno / TypeScript)

Deploy with `supabase functions deploy <name>`. These run with the **service-role key** (set as a function secret) so they can write across users.

### `ai-generate`
Generates text with Claude/OpenAI. Two modes:
- **follow-up message** — input: contact (name, status, met context, day_offset) → output: a warm, personalised follow-up draft. Stored on `followups.message` for the user to edit/send.
- **daily encouragement** — input: optional theme → output: a short encouragement line to accompany the day's verse.

```
POST /functions/v1/ai-generate
{ "mode": "followup", "contact_id": "…", "day_offset": 7 }
→ { "message": "Hi Sarah! So glad we connected…" }
```
The AI provider key is a function secret; never call the AI API from the app.

### `process-followups`  (invoked by cron, see §3)
For every contact whose follow-up is due today, ensure a `followups` row exists, optionally call `ai-generate` to draft the message, create a `notifications` row, and trigger `send-push`.

### `send-push`
Fan-out to FCM. Input: `user_id` (or list) + `{title, body, data}`. Looks up `devices.fcm_token` for the user(s) and calls the **FCM HTTP v1** API. Used for follow-up reminders, daily encouragement, "someone encouraged your testimony", and event reminders.

### `award-achievements`  (invoked after activity / by cron)
Checks unlock criteria against `profiles` stats and `activity_logs`, inserts into `user_achievements`, and pushes a congratulations notification. (Kept server-side so badges can't be spoofed by the client.)

### `daily-mission`  (invoked by cron)
Selects the day's verse, builds the `daily_missions.tasks` array for each active user, and (if `daily_reminder_enabled`) sends the encouragement push.

### `sweep-presence`  (invoked by cron, frequent)
Deletes `live_presence` rows past `expires_at`, so the map self-cleans even if a client crashes without ending its session.

## 3. Scheduled jobs (pg_cron)

| Job | Schedule | Action |
|-----|----------|--------|
| Process follow-ups | daily 13:00 UTC | call `process-followups` (find due follow-ups, draft + notify) |
| Daily mission + encouragement | daily 12:00 UTC (user-local windows later) | call `daily-mission` |
| Presence sweep | every 2 min | call `sweep-presence` |
| Streak-risk nudge | daily 23:00 local-ish | push users whose streak is at risk and who haven't logged today |

Example (`pg_cron` calling an Edge Function via `pg_net`):
```sql
select cron.schedule('sweep_presence','*/2 * * * *', $$
  select net.http_post(
    url := 'https://<project>.functions.supabase.co/sweep-presence',
    headers := jsonb_build_object('Authorization','Bearer '||current_setting('app.service_key'))
  );
$$);
```

## 4. Realtime

### Live map presence
While a session is live the app joins a presence channel and tracks its position; it also upserts `live_presence` every ~15 s (the durable copy for geo queries).

```dart
final channel = supabase.channel('evangelists');
channel.onPresenceSync((_) => updatePinsFromPresenceState(channel.presenceState()));
await channel.subscribe();
await channel.track({'user_id': uid, 'lat': lat, 'lng': lng, 'is_evangelizing': true});
// every 15s: supabase.from('live_presence').upsert({...});
```

The Map/Nearby views combine two sources: `nearby_evangelists()` for the authoritative, fuzzed set on load/refresh, and presence events for instant join/leave animation between refreshes.

### Live community feed
Subscribe to Postgres Changes so new posts/reactions/comments appear without a manual refresh:
```dart
supabase.channel('feed')
  .onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'posts',
      callback: (p) => prependPost(p.newRecord))
  .subscribe();
```

### Own dashboard
Subscribe to `activity_logs` filtered to `user_id = me` to update streak/impact instantly after logging.

## 5. AI integration details

- **Where:** only inside Edge Functions (`ai-generate`), with the provider key as a secret.
- **Follow-up prompt shape:** system role = "You write warm, brief, non-pushy follow-up messages for a Christian evangelist"; user content = contact's first name, spiritual status, where/how they met, the day in the sequence, and a nearby church if connecting. Return 1–3 sentences.
- **Daily encouragement:** short, Scripture-anchored, never preachy; rotate themes (boldness, perseverance, compassion).
- **Guardrails:** cap tokens, strip PII beyond first name in prompts, log nothing sensitive, and always let the user edit before anything is sent.

## 6. Push notifications (FCM)

- App registers its FCM token on launch/login → upsert `devices`.
- All sends go through `send-push` (service-role) using FCM HTTP v1.
- Categories: follow-up due, daily encouragement/streak nudge, social (encouraged/commented), event reminder, achievement unlocked.
- Respect `profiles.daily_reminder_enabled` and (future) per-category preferences.

## 7. Storage

- Upload via `supabase.storage.from('bucket').uploadBinary('{uid}/{file}', bytes)`.
- Buckets and policies per `03-security-rls.md` (`avatars` public, `selfies` private/signed URLs, `posts` public).
- Generate signed URLs for private selfies: `createSignedUrl(path, 3600)`.

## 8. Putting it together — "End Session" sequence

1. App calls `end_session(session_id, cv, pr, pa)` (RPC) → sets `ended_at`, `duration_seconds`, `status='completed'`, writes the counters, and inserts `activity_logs` (one per conversation/prayer; `people_added` already logged on contact insert).
2. The `apply_activity_stats` trigger updates cached stats + streak.
3. `award-achievements` runs (e.g., first salvation, 7-day streak) and may push a badge.
4. App shows the Session Summary; "Share Testimony" pre-fills the composer (`posts.insert`).
