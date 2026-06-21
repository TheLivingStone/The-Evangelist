# The Evangelist — Admin Dashboard

Internal, owners-only web dashboard for The Evangelist. Lets you see **all**
users, posts, churches, and aggregate stats in one place, moderate posts, and
verify churches.

**This is separate from the Flutter app and is never shipped to end users.**

## How it stays secure

- Built with **Next.js (App Router)**. All database access uses the Supabase
  **service-role key**, which lives **only in server code** (`lib/supabaseAdmin.ts`,
  guarded by `import "server-only"`). It is never sent to the browser.
- Access is gated by a **single shared admin password** (`ADMIN_PASSWORD`).
  Logging in sets a signed, httpOnly session cookie (HMAC-SHA256, 12h expiry).
- `middleware.ts` redirects any unauthenticated request to `/login`. Privileged
  server actions (`app/actions.ts`) re-check the session before writing.

## Setup

1. Install dependencies:
   ```bash
   cd admin
   npm install
   ```
2. Create `.env.local` from the template and fill in the three secrets:
   ```bash
   cp .env.example .env.local
   ```
   - `SUPABASE_SERVICE_ROLE_KEY` — Supabase Dashboard → Project Settings → API →
     `service_role` (secret). **Treat like a master password.**
   - `ADMIN_PASSWORD` — the password you type to log in. Make it long & random.
   - `ADMIN_SESSION_SECRET` — generate one:
     ```bash
     node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
     ```
3. Run it:
   ```bash
   npm run dev
   ```
   Open http://localhost:3100 and enter your admin password.

## What each page does

| Page | What it shows / does |
|------|----------------------|
| **Overview** | Totals: users, salvations, conversations, posts, churches, verified count; new users/posts in the last 7 days. |
| **Users** | Every profile (newest first) with city, church, streak, and lifetime stats. |
| **Posts** | Every community post with author, type, body, photo. **Delete** removes it for everyone (moderation). |
| **Churches** | Every registered church. **Verify / Unverify** toggles `is_verified`. |

## Note on emails

User **emails and login identity live in Clerk, not Supabase** — so they are not
shown here. `profiles` holds the public profile + stats only. To add emails:
call the Clerk Backend API with `CLERK_SECRET_KEY` server-side (e.g. in
`lib/data.ts`, map `profiles.id` → Clerk user → email) and render a column.

## Security posture & known advisories

Pinned to **Next.js 14.2.35** (latest 14.2.x). This patches the two advisories
that matter for how this app is built:
- Middleware SSRF / redirect handling (CVE-2025-57822) — patched in 14.2.32.
- Server Actions DoS (GHSA-7m27-7ghc-44w9) — patched in 14.2.21.

`npm audit` will still report Next as "high" because it reports the *aggregate*
advisory range and can only auto-fix by jumping to Next 16 (a breaking change).
The remaining flagged items do **not** apply to this app as built:
- **Image Optimizer `remotePatterns` DoS (GHSA-9g9p-9gw9-jx7f)** — no 14.x patch
  exists, BUT we set `images.unoptimized: true` and render photos with plain
  `<img>` tags, so the optimizer endpoint is never used. Do **not** switch to
  `next/image` without upgrading Next and re-reviewing this.
- **HTTP smuggling in rewrites / i18n bypass** — we use no rewrites or i18n.
- **postcss `</style>` XSS (moderate)** — build-time only, on CSS we author
  ourselves (all static). Not attacker-reachable.

**Recommended follow-up:** migrate to **Next.js 15.5.10+** (or 16.x) when you
have a moment — it clears the full advisory list. It's a breaking upgrade
(mostly async `cookies()`/`headers()` and config changes), so it was kept out of
the initial build. Until then, 14.2.35 with the mitigations above is sound for
an internal, password-gated tool.

## Deploying (later)

Deploys cleanly to **Vercel** (free tier). Set the same env vars in the Vercel
project settings. Because the service-role key is server-only, it stays safe.
Restrict who can reach the deployment (Vercel password protection or your own
allowlist) as a second layer on top of `ADMIN_PASSWORD`.
