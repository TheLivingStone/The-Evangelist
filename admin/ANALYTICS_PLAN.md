# The Evangelist — Admin Analytics Dashboard Plan

> **STATUS (built 2026-06-21):** Fully implemented end-to-end. 7 admin pages
> (Overview, Growth & Acquisition, Map, Kingdom Impact, Community, Users,
> Churches) with Recharts + MapLibre; church-membership fruitfulness feature
> (members claim a church, churches confirm them, evangelism rolls up per
> church); signup-source attribution. **TO TURN ON:** run these two files in the
> Supabase SQL Editor (project `ryufvbhddsntcrvpkpet`):
> `supabase/migrate_admin_analytics.sql` and `supabase/migrate_church_members.sql`.
> Until then, pages render with a "not turned on yet" banner (no crash).


> A complete inventory of everything we can track, broken down into a beautiful,
> data-rich admin dashboard. Designed so that when we run growth/user-acquisition
> campaigns, we can see **what's working and what's not** at a glance.
>
> Visual language matches the app: dark-first, `#FF6B00` orange accent, Roboto,
> Material-3 rounded surfaces. Built on the existing Next.js admin in `admin/`.

---

## 1. What data exists (the raw material)

The Supabase backend has **20 tables + 2 views + several geo RPCs**. Almost
everything has a `created_at`/timestamp (→ time-series), a category/enum
(→ pie/bar), or a `geography(Point)` location (→ maps). That's the gold mine.

### Tables grouped by what they measure

| Domain | Tables | Key signals |
|---|---|---|
| **People / Growth** | `profiles`, `devices` | signups over time, city, ministry, platform (iOS/Android), theme, retention via `last_evangelism_date` |
| **Kingdom impact** | `activity_logs`, `outreach_sessions`, `profiles.total_*` | conversations, salvations, prayers, follow-ups, church connections — over time, by type, by location |
| **CRM / contacts** | `contacts`, `followups` | spiritual-status funnel, follow-up channel mix & completion, "people met" pipeline |
| **Community / Social** | `posts`, `comments`, `post_reactions`, + count views | post volume by type, reactions sentiment, comment depth, top posts/authors |
| **Churches** | `churches` | registrations, verification rate, claim funnel (unclaimed→pending→approved/rejected), density map |
| **Events** | `events`, `event_attendees` | events scheduled, RSVP growth, attendance per event |
| **Gamification** | `achievements`, `user_achievements`, `daily_missions` | achievement unlock distribution, mission completion rate, streaks |
| **Engagement infra** | `notifications`, `live_presence` | notification volume & read rate, live evangelists right now |
| **Geo (maps)** | `live_presence`, `churches`, `outreach_sessions`, `activity_logs`, `posts`, `events` | every one carries a `geography(Point,4326)` |

### Geographic columns (for the map view)
`live_presence.location` (fuzzed), `churches.location` (exact), `outreach_sessions.location`, `activity_logs.location`, `posts.location`, `events.location`.

### Categorical fields (for pie / bar / donut)
spiritual_status, activity_type, post_type, reaction_type, followup_status, session_status, churches.claim_status, devices.platform, profiles.theme, ministry, city.

### Time fields (for trend lines / area charts)
`activity_logs.occurred_at` (the master event stream), plus `created_at` on profiles, posts, comments, churches, events, contacts; `started_at`/`ended_at` on sessions; `earned_at` on achievements; `mission_date` on daily missions.

---

## 2. The dashboard, page by page

Seven pages. The first three are net-new analytics; the last three upgrade what
exists today (Users / Posts / Churches) into rich, filterable, charted views.

### A. **Overview** (executive cockpit) — upgrade of current home
The "everything at a glance" screen.

- **KPI strip (8 cards, each with a sparkline + WoW %):** Total users, New users (7d/30d), Salvations, Gospel conversations, Prayers, Posts, Churches verified/total, Live evangelists now.
- **Growth chart** — daily/weekly new users (area chart), toggle 7/30/90 days.
- **Kingdom impact over time** — stacked area of activity_logs by type (conversation/salvation/prayer/followup/church_connection).
- **Activity mix** — donut of activity types share.
- **Funnel** — Signed up → Logged first activity → Added a contact → Recorded a salvation (the core product funnel).
- **Live now** — count + mini list of evangelists currently active (`live_presence`).
- **Recent events feed** — newest signups, salvations, posts, church registrations (a live "pulse" column).

### B. **Growth & Acquisition** (the campaign page you specifically asked for) ⭐
This is where you judge whether a campaign is working.

- **New users by day** with a date-range picker and **before/after markers** so you can annotate a campaign launch and visually see the lift.
- **Cumulative users** (the "up and to the right" line).
- **New users by city** (bar) and **by platform** (iOS vs Android donut) — tells you *where* and *on what device* new users come from.
- **Activation rate** — % of new signups who logged ≥1 activity within 7 days (the single most important campaign-quality metric).
- **Cohort retention grid** — weekly signup cohorts × weeks-since-signup, colored by % still active (classic retention heatmap). Shows if a campaign brings *real* users or tourists.
- **Day-1 / Day-7 / Day-30 retention** summary cards.
- **Funnel conversion** with drop-off % at each step.
- *(Campaign attribution note: we don't capture UTM/referrer yet — see §5 for the small backend add that unlocks true per-campaign breakdowns.)*

### C. **Map View** (geographic intelligence) ⭐
A full interactive map, dark-themed to match.

- **Heatmap layer** of activity_logs / outreach_sessions — where is evangelism actually happening?
- **Church markers** — color-coded by verification status; click for details.
- **Live evangelists** — fuzzed dots from `live_presence` (privacy-respecting).
- **Posts & events** with location.
- **Layer toggles** (heatmap / churches / live / posts / events) + city filter.
- **Side panel**: per-city rollup — users, salvations, churches, active evangelists.

### D. **Kingdom Impact** (the mission metrics)
The numbers that matter spiritually, made beautiful.

- Big counters: total salvations, conversations, prayers, follow-ups, church connections.
- **Salvations over time** (area), **conversion ratio** (salvations ÷ conversations) trend.
- **Leaderboard** — top evangelists by salvations / conversations / streak (with avatars).
- **Streak distribution** histogram; count of users on active streaks.
- **Achievements** — unlock distribution bar (which badges are common vs rare), unlocks over time.
- **Contact funnel** — spiritual_status breakdown (new_contact → … → active) as a horizontal funnel.

### E. **Community & Content** — upgrade of current Posts page
- KPI cards: total posts, posts (7d), avg reactions/post, avg comments/post, total reactions, total comments.
- **Posts over time** by type (stacked area).
- **Post type mix** donut; **reaction sentiment** donut (encouraged/inspired/praying/amen).
- **Top posts** (by reactions+comments) and **most active authors** tables.
- **Moderation table** (keep existing delete) but filterable by type/city/date + search.

### F. **Users** — upgrade of current Users page
- Filters: city, ministry, has-activity, date-joined range; search by name/username.
- Sortable columns; **per-user detail drawer** showing their activity timeline, contacts count, posts, achievements, streak history.
- Cards: total, active (last 7d), dormant, never-activated.
- Platform & city distribution mini-charts at the top.

### G. **Churches** — upgrade of current Churches page
- Keep the vetting queue (verify/reject) but add:
- Cards: total, verified, pending, rejection rate.
- **Claim funnel** (unclaimed → pending → approved/rejected).
- **Registrations over time**; **churches by city** bar; map preview of church density.

---

## 3. Chart & component inventory (so it looks pro, not boring)

- **KPI cards** with embedded sparkline + period-over-period delta (green up / red down).
- **Area / line charts** — growth, impact-over-time, cumulative.
- **Stacked area / bar** — activity mix and post mix over time.
- **Donut / pie** — categorical shares (activity type, post type, reactions, platform, claim status).
- **Funnel charts** — product funnel + contact spiritual funnel.
- **Cohort retention heatmap** — the campaign-quality centerpiece.
- **Leaderboard tables** with avatars + rank medals.
- **Histogram** — streak distribution.
- **Interactive map** with heatmap + markers + layer toggles.
- **Live pulse feed** — recent events, auto-refreshing.
- **Date-range picker** + segmented period toggles (7d / 30d / 90d / all), global to the page.

---

## 4. How it gets built (technical approach)

- **Charts:** add **Recharts** (React-native to Next, themeable, lightweight, composable) for line/area/bar/pie/funnel/heatmap.
- **Map:** **MapLibre GL** (open-source, no token needed) with a dark style + `react-map-gl`, or Leaflet if we prefer raster tiles. Heatmap via MapLibre's built-in heatmap layer.
- **Data:** add a `lib/analytics.ts` of server-side aggregate queries. Heavy
  rollups (time buckets, cohorts, geo) become **Postgres RPCs / SQL views** so
  the DB does the grouping (fast, correct) instead of pulling rows to Node.
- **Design:** reuse the existing CSS variables; add a small chart-theme so every
  chart uses the same orange/green/blue/purple palette already in the app.
- **Structure:** new routes under `app/(dashboard)/` — `growth/`, `map/`,
  `impact/`, plus upgraded `users/`, `posts/`, `churches/` and `page.tsx`.
- **Performance:** keep `force-dynamic` but add light caching (e.g. 60s) on the
  expensive rollups so the page stays snappy.

---

## 5. Small backend adds that unlock big analytics wins

These are optional but high-leverage, especially for campaigns:

1. **Aggregation SQL views/RPCs** — `daily_signups`, `daily_activity_by_type`,
   `activation_funnel`, `cohort_retention`, `city_rollup`, `geo_activity_points`.
   (No new user data — just fast server-side rollups of what we already store.)
2. **Acquisition source on signup** — add `signup_source` / `utm_*` columns to
   `profiles` (or a small `signup_events` table), captured at registration. This
   is what turns "new users went up" into "**this campaign** drove 40 signups,
   12 activated." Highest-value add for measuring campaigns.
3. **Event/page analytics** (later) — a lightweight `app_events` table or
   PostHog/Plausible if you want screen-level funnels inside the app itself.

---

## 6. Suggested build order

1. Chart + map libraries installed, shared chart theme wired to app colors.
2. Aggregation SQL views/RPCs deployed to Supabase.
3. **Overview** cockpit (KPIs + sparklines + growth + impact + funnel + pulse).
4. **Growth & Acquisition** (cohorts, activation, retention) — the campaign page.
5. **Map View**.
6. **Kingdom Impact** (leaderboards, achievements, contact funnel).
7. Upgrade **Users / Community / Churches** with filters + charts.
8. (Optional) acquisition-source capture for true campaign attribution.
