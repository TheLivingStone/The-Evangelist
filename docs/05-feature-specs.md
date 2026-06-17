# 05 · Feature Specs (per screen)

Each spec maps a screen from the prototype to its data, writes, realtime, and edge cases. Table and function names refer to `02-data-model.md` and `04-backend-logic.md`.

---

## Navigation shell

Bottom tab bar (5 slots): **Dashboard · Community · ➕ Start · Map · Profile**. The centre **➕ Start** is a raised FAB that opens the *What happened today?* bottom sheet — it is not a tab/screen. "My People" (contacts) is reached from that sheet, not from the tab bar.

---

## ➕ Start — the movement sheet

**Purpose:** the core action of the app. A bottom sheet with five options.

| Option | Action | Writes |
|--------|--------|--------|
| Start Outreach Session | open Session-Live, begin timer + presence | insert `outreach_sessions` (status `live`); upsert `live_presence` |
| Add Person | open Add-Person form | insert `contacts` (+ `activity_log` type `followup`? no — person add only) |
| Log Conversation | quick log, no contact needed | insert `activity_logs` (type `conversation`) |
| Log Prayer | quick log | insert `activity_logs` (type `prayer`) |
| Create Testimony Post | open composer | insert `posts` |

**Edge cases:** if a session is already live, "Start Outreach Session" resumes it instead of creating a second. Quick logs attach `session_id` when a session is live.

---

## Dashboard

**Purpose:** motivate; show streak, mission, impact, reminders.

**Data sources**
- Greeting + streak: `profiles` (current_streak, last_evangelism_date, weekly_goal).
- Weekly mission: count of distinct days with activity this week from `activity_logs` vs `weekly_goal`; OR a `weekly_missions` derived value.
- Impact This Month: counts from `activity_logs` for the current month grouped by `type` (conversations, salvations, follow-ups, church connections), plus the "+N this month" deltas.
- Follow-Up Reminders: `contacts` where `next_followup_at <= today` ordered by date (limit 3) → "View all" opens My People filtered.
- Daily Encouragement entry: links to the Encouragement screen.

**Writes:** none directly (read-only dashboard). **Realtime:** subscribe to own `activity_logs` to refresh stats live after a log.

**Edge cases:** new user with no data shows encouraging empty states ("Log your first outreach to start your streak"). Streak shows 0, mission 0/goal.

---

## Community (feed)

**Purpose:** a focused, Twitter-style evangelism feed.

**Layout:** header + search; a compose bar ("Share what God did today…") that opens the composer; Twitter-style tabs **For You · Testimonies · Outreach · Prayer · Nearby**; then the feed.

**Data sources**
- For You: `posts` where `is_public` ordered by `created_at desc` (later: rank by recency + followed authors).
- Testimonies/Outreach/Prayer: same, filtered by `type`.
- Reaction counts: `post_reaction_counts` view; whether *I* reacted: my rows in `post_reactions`.
- **Nearby tab:** switches the feed for the **live map view** (see below) — `nearby_evangelists()` + a list of live evangelists with distance.

**Post card:** avatar, name, city/church/ministry, time; body; optional photo; reactions **🔥 Encouraged · 🙏 Praying · 💬 Comment · ↗ Share**. Outreach posts render a **Join Outreach** banner (writes `event_attendees`). Prayer posts emphasise **🙏 I'm praying**.

**Writes:** reactions → upsert/delete `post_reactions`; comment → insert `comments`; join → insert `event_attendees`.

**Realtime:** subscribe to `posts`, `post_reactions`, `comments` so the feed and counts update live.

**Edge cases:** tapping an author opens their **public profile**. No likes, no follower counts, no ranking. Empty Nearby state when no one is live nearby: "No one evangelising near you right now — be the first."

---

## Community → Nearby / Map tab (live map)

**Purpose:** show people evangelising **right now**.

**Data sources:** `nearby_evangelists(lat,lng,radius)` for fuzzed pins; `area_stats(...)` for the sheet ("12 Evangelists · 5 Outreaches Today · 3 Churches Nearby"); `nearby_churches(...)` for church pins; Realtime presence for instant join/leave.

**Behaviour:** request location permission; render Google Map; drop animated pins for live evangelists (with name + green "live" dot), the user's own position, and churches. The bottom sheet shows area stats + "View Area".

**Writes:** none (read-only). The viewer only appears to others if *they* are in a live session with `is_visible_on_map = true`.

**Edge cases:** location denied → show a permission explainer and a static city view. Privacy: never request or show exact coordinates of others (RPC fuzzes them).

---

## My People (contacts — opened from ➕ Start)

**Purpose:** the evangelism CRM.

**Data sources:** `contacts` where `owner_id = me`; filter chips (All/New/Follow-Up/Church/Active) map to `status`; search by name. Each row: avatar, name, met context, status pill, due badge (from `next_followup_at`).

**Writes:** none on list; row tap → Person Profile.

**Edge cases:** empty state prompts "Add the first person you meet." Due-today contacts sort to top.

---

## Add Person

**Purpose:** save someone met (and start their follow-up).

**Fields → columns:** photo → `selfie_url` (Storage `selfies` bucket), first/last name, phone, email, met_location (`met_location`), what happened (`notes`), spiritual status (`status`), next follow-up (`next_followup_at`), notes.

**On Save:** insert `contacts`; if status warrants, create the Day 1/3/7/14/30 `followups` rows (scheduled relative to today); optionally insert an `activity_logs` row of type `followup` is *not* created here (adding a person ≠ an outreach) — but if added during a live session, increment `people_added_count`.

**Edge cases:** offline → queue in outbox with a client UUID. Phone/email optional; first name required.

---

## Person Profile (a contact)

**Purpose:** manage one relationship and its follow-up.

**Data sources:** one `contacts` row; its `followups` timeline (Day 1/3/7/14/30 with status); quick actions Call / Message / Note / More; spiritual status; tags; next follow-up.

**Writes:** edit contact (`contacts.update`); send a follow-up → mark `followups.status='sent'`, set `sent_at`; "AI-Suggested Message" calls `ai-generate` then lets the user edit before sending; logging a conversation here inserts `activity_logs` linked to this `contact_id`; changing status updates `contacts.status`.

**Edge cases:** completing a follow-up advances the timeline and may schedule the next; connecting to a church writes `activity_logs` (type `church_connection`, with `church_id`).

---

## Public Profile (another evangelist, from Community)

**Purpose:** see and encourage another evangelist — inspiring, not competitive.

**Data sources:** their `profiles` (name, city, church, bio, avatar); public outreach stats (their lifetime totals); recent `posts` (testimonies); `groups` they belong to; recent activity (public only).

**Actions:** **Message** (future DM or deep-link), **Pray for {name}** (records an encouragement/notification to them), **View Testimonies** (their public posts).

**Edge cases:** no rankings or "top evangelist." Respect that some stats may be hidden by the user later (privacy setting, future).

---

## Outreach Session — Live

**Purpose:** track a live evangelism session.

**State:** running timer (client), counters for Conversations / Prayers / People Added (tap +1). Location card shows `location_name` + signal.

**Writes:** on start, insert `outreach_sessions` (status `live`) and begin presence (`live_presence` upsert + Realtime track every ~15 s). Each +1 can either update the session counters immediately or be tallied and written on end. End → `end_session` RPC writes counters + `activity_logs`, sets `status='completed'`, stops presence.

**Edge cases:** app backgrounded → keep timer via stored `started_at`; if the app dies, `sweep-presence` removes the stale pin after `expires_at`. Pause stops the timer but keeps the session live.

---

## Outreach Session — Summary

**Purpose:** celebrate and convert effort into a post.

**Data sources:** the just-ended `outreach_sessions` row (duration + counters).

**Actions:** **View Recap** → Dashboard; **Share Testimony** → composer pre-filled with the session stats (`posts.insert`, type `outreach` or `testimony`). Achievement unlocks (from `award-achievements`) surface here.

---

## Map (full Live Map tab)

Same data and privacy model as Community → Nearby, full-screen, with the area sheet and "View Area." Primary destination for "who's out right now."

---

## Daily Encouragement

**Purpose:** a daily word + a tiny mission to keep the habit.

**Data sources:** today's `daily_missions` row (verse + tasks). "New Verse" cycles `verses`. Tasks (Pray for boldness / Share the Gospel / Encourage another evangelist) are checkable.

**Writes:** toggling a task updates `daily_missions.tasks`; completing all sets `completed=true` (can award XP/streak credit). "I'm on it!" returns to Dashboard.

---

## Profile (own)

**Purpose:** identity, impact, achievements, settings.

**Data sources:** `profiles` (name, church, city, avatar); lifetime totals; `user_achievements` (earned) joined to `achievements` (catalog) for the badge grid; `longest_streak`.

**Writes:** edit profile; toggle `theme` (dark/light), `daily_reminder_enabled`, `is_visible_on_map` in settings.

**Edge cases:** locked achievements render greyed from the catalog minus earned. Theme toggle persists to `profiles.theme` and applies app-wide.

---

## Cross-cutting requirements

- **Offline-first** for own data (contacts, logs, sessions, dashboard) per `01-architecture.md`.
- **Empty & error states** on every screen (no data, no permission, no network).
- **Accessibility:** dynamic type, sufficient contrast in both themes, semantic labels.
- **Analytics:** track the North-Star (Active Evangelist = activity in last 7 days) plus session starts, logs, posts, reactions.
