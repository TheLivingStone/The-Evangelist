# 03 · Security & Row-Level Security

The runnable policies live in [`/supabase/policies.sql`](../supabase/policies.sql). This document explains the access model and the privacy design — especially for the live map, which is the most sensitive surface.

## Trust model

- The **mobile app** authenticates with the Supabase **anon key + the signed-in user's JWT**. Every query is therefore subject to Row-Level Security (RLS). `auth.uid()` is the current user.
- **Privileged work** (push fan-out, AI calls, awarding achievements, cron jobs, processing follow-ups) runs server-side in **Edge Functions / SQL jobs using the service-role key**, which bypasses RLS. The service-role key is never shipped in the app.
- **RLS is enabled on every table.** With RLS on and no matching policy, access is denied by default — so we explicitly grant only what each role needs.

## Access matrix

| Table | Read | Write |
|-------|------|-------|
| `profiles` | any authenticated user (public identity) | owner only (`id = auth.uid()`) |
| `contacts` | **owner only** | owner only |
| `followups` | owner only | owner only |
| `outreach_sessions` | owner only | owner only |
| `activity_logs` | owner only | owner insert only — **append-only** (no update/delete) |
| `churches` | public (authenticated) | any authed can add; only `claimed_by` edits |
| `events` | public | host manages |
| `event_attendees` | public | join/leave own row |
| `posts` | public (`is_public`) or author | author only |
| `post_reactions` | public | own rows only |
| `comments` | public | author only |
| `live_presence` | **no direct select** (RPC only) | own row only |
| `groups` / `group_members` | public | creator / own membership |
| `achievements` / `verses` | public catalog | service-role only |
| `user_achievements` | owner only | service-role only |
| `daily_missions` | owner only | owner only |
| `notifications` | owner only | owner can mark read; created by service-role |
| `devices` | owner only | owner only |

## Privacy: the live map

This is the part to get right. People's real-time location is involved, so:

1. **No client ever reads `live_presence` directly.** There is deliberately *no* SELECT policy on that table. Clients call the `nearby_evangelists(lat, lng, radius)` RPC instead.
2. **Locations are fuzzed.** The RPC rounds coordinates to ~3 decimal places (~110 m) before returning them, so exact positions are never exposed — only an approximate pin.
3. **Opt-in visibility.** The RPC filters on `profiles.is_visible_on_map`. A user who toggles off "Show me on the map" disappears from everyone's results immediately.
4. **Liveness + expiry.** Only rows that are `is_evangelizing` and not past `expires_at` are returned, so pins vanish shortly after someone stops or goes offline.
5. **Self excluded.** `p.id <> auth.uid()` keeps you from seeing your own pin in the nearby list.

The same `security definer` pattern powers `nearby_churches()` and `area_stats()` for the map sheet.

## Auth configuration (Supabase Auth / GoTrue)

- **Providers:** Email/password, **Google**, and **Apple** (Apple Sign-In is *required* by App Store review when other social logins are offered).
- **Profile bootstrap:** the `handle_new_user` trigger (in `schema.sql`) creates a `profiles` row automatically on signup, seeding `full_name`/`username` from the auth metadata.
- **JWT:** default Supabase JWT; `auth.uid()` and `auth.jwt()` are available inside policies and functions.
- **Email verification / password reset:** use Supabase's built-in flows; customise templates with The Evangelist branding.
- **Deep links:** configure the app's redirect URL scheme for OAuth and magic-link callbacks.

### Implementation status & history (as of 2026-06-21)

The app uses **Supabase Auth**, matching this spec and the live database (`profiles.id` and all user-id columns are `uuid`; RLS uses `auth.uid()`).

> **Historical note — the Clerk detour.** The Flutter code was briefly migrated to **Clerk** (text user ids, `auth.jwt()->>'sub'`), but the **live database was never changed** — it stayed Supabase Auth. That mismatch broke writes the moment the backend was enabled. The code was reverted to Supabase Auth on 2026-06-21 to match the DB. **Do not reintroduce Clerk** without also migrating every `*_id` column to `text` and rewriting all 41 RLS policies. The old `clerk-supabase-integration` notes are historical only.

Key facts the spec doesn't state:
- **Profiles are created DB-side, not by the app.** The `handle_new_user` trigger inserts the row; `profiles` has **no INSERT policy** (only SELECT + UPDATE). The app's `ProfileRepo.ensure()` only *reads* the trigger-created row. Never add a client-side `profiles` insert.
- **Display name flow:** the auth screen calls `signUp(data: {'full_name': ...})` → lands in `raw_user_meta_data` → the trigger copies it to `profiles.full_name`.
- **Live gotchas to finish before public launch:**
  - **Email confirmation is currently ON** — new signups must confirm by email before login. Turn OFF in the dashboard (Auth → Providers → Email → "Confirm email") for frictionless testing, re-enable for production as desired.
  - **Google sign-in** has a working button in the app but requires a Google OAuth client to be configured in Supabase (Auth → Providers → Google) before it functions; until then it fails gracefully. **Apple Sign-In** is still TODO and is required by App Store review.
  - App config: `BACKEND_ENABLED=true` in `app/.env` connects the app to live Supabase + Auth (vs. in-memory demo mode).

## Storage security (Supabase Storage)

Three buckets, each with policies:

| Bucket | Contents | Policy |
|--------|----------|--------|
| `avatars` | profile photos | public read; write only to `avatars/{auth.uid()}/…` |
| `selfies` | contact selfies | **private**; read/write only by the contact's owner (`selfies/{auth.uid()}/…`) |
| `posts` | outreach photos | public read; write only to `posts/{auth.uid()}/…` |

Enforce the `{auth.uid()}` path prefix in a Storage policy so users can only write to their own folder. Private buckets (selfies) are served via short-lived signed URLs.

## Data-protection principles (from the product spec)

- Collect the minimum: name, phone, optional email, city. **Do not collect home addresses.**
- Users control map visibility (`is_visible_on_map`); location shown is always approximate.
- Provide account deletion: deleting `auth.users` cascades to all owned rows via `on delete cascade`.
- A clear privacy policy is required before store submission (both Apple and Google mandate it, especially given location use).

## Abuse & moderation (community)

- All posts/comments are attributable to a profile (no anonymous posting).
- Add a `reports` table (future) and a soft-delete/hide path for moderators; keep basic rate limits on `posts`/`comments` via an Edge Function or `pg` rate check.
- Reactions are mission-specific and capped one-per-type per user by the composite primary key, which structurally prevents brigading/duplicate spam.
