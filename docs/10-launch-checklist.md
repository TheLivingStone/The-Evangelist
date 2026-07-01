# 10 · App Store Launch Checklist (The Evangelist)

The exact, ordered steps to get this app live on the iOS App Store. Items marked
**[CODE ✅]** are already done in the repo (on the `launch-prep` branch). Items
marked **[YOU]** only you can do — they need your Apple account, your Supabase
project, or your legal identity.

Auth model: **Supabase Auth** (email/password + Sign in with Apple), with an
anonymous "guest" session at launch that upgrades to a real account when a guest
tries a real-account action.

---

## A. Already done in code (launch-prep branch) [CODE ✅]

- Reconciled all Supabase SQL to the Supabase Auth model (uuid / `auth.uid()`),
  added the `handle_new_user` trigger, validated the whole stack against Postgres.
- In-app **account deletion** — `delete-account` Edge Function + a "Delete
  account" button in Profile settings (Apple Guideline 5.1.1(v)).
- `Info.plist`: added `ITSAppUsesNonExemptEncryption=false`; removed the Google
  URL-scheme placeholder (v1 is Email + Apple).
- Sign in with Apple entitlement present and wired into the Xcode project.
- Guest writes (post, react, comment, register/claim church) gated behind
  account creation.
- FAB lowered; map shows demo data in local mode; minor perf cleanups.
- **App privacy manifest** `ios/Runner/PrivacyInfo.xcprivacy` created and wired
  into the Runner target (declares: email, name, coarse location, photos, user
  content — all "app functionality", not tracking, not sold). Apple now requires
  this; it only bundles in a real signed Archive build, not `--no-codesign`.
- **Privacy policy draft** at `docs/privacy-policy.md` — fill in the date + your
  legal name, host it publicly, and paste the URL into App Store Connect (step D5).
- Map redesigned: dark CARTO street tiles + glowing dots + tap-to-reveal card.

> Status note (verified 2026-06-27): anonymous sign-ins, "allow new signups",
> and Apple provider can all be toggled in Supabase. **Captcha is currently OFF**
> (it was blocking all signups incl. guest). Fine for review; consider proper bot
> protection before heavy public traffic.

> These are committed on `launch-prep`. Merge that branch (plus the existing
> working-tree changes) into `main` before you build for release.

---

## B. Stand up YOUR backend [YOU]

1. Create a Supabase project at supabase.com (region near your users). Save the
   DB password.
2. **Database → Extensions**: enable `postgis` and `pg_cron`.
3. **SQL Editor**: paste and run **`supabase/migrate_all.sql`** (one shot:
   reset → schema → policies). Then run, in any order:
   `migrate_church_members.sql`, `migrate_church_registration.sql`,
   `migrate_feed_comments_photos.sql`, `migrate_admin_analytics.sql`.
4. **Authentication → Providers**:
   - Enable **Anonymous sign-ins** (the app's guest mode depends on this).
   - Enable **Apple**. Fill in the values from step D below.
   - (Email is on by default. Turn OFF "Confirm email" for the simplest flow,
     or keep it on and tell App Review.)
5. **Edge Functions**: deploy the account-deletion function:
   ```bash
   supabase functions deploy delete-account
   ```
   (It uses `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`, which Supabase injects
   automatically. No manual secrets needed.)
6. **Project Settings → API**: copy your **Project URL** and **anon/publishable
   key**.

## C. Point the app at your backend [YOU]

In `app/.env` set:
```
BACKEND_ENABLED=true
SUPABASE_URL=<your project url>
SUPABASE_ANON_KEY=<your anon/publishable key>
```
(Leave the Google keys empty for v1.) Then:
```bash
cd app && flutter pub get && flutter run --release
```
Sign up, log an activity, post, delete your account — confirm each works against
the live backend.

---

## D. Apple Developer + App Store Connect [YOU]

1. **Enroll** in the Apple Developer Program ($99/yr) at developer.apple.com →
   Account → Enroll. Individual is approved in ~1–3 days.
2. **Register the bundle ID** (developer.apple.com → Identifiers). Use the
   project's existing bundle id (the Xcode "The Evangelist" target). Enable the
   **Sign in with Apple** capability on that App ID.
3. **Sign in with Apple service config** (for Supabase): create the Service ID +
   key per docs/09-google-apple-signin.md, and paste the Service ID, Team ID,
   Key ID, and key into Supabase → Auth → Apple (step B4).
4. **App Store Connect** (appstoreconnect.apple.com) → My Apps → + → New App:
   platform iOS, the bundle id, an SKU (e.g. `evangelist-001`), primary language.
5. **App Information**: category (Lifestyle or Reference), subtitle, and your
   **privacy policy URL** (mandatory — host a simple page; the app uses location
   + accounts, so this is required).
6. **App Privacy** ("nutrition labels"): declare what you collect — account info
   (email/name), contacts the user enters, approximate location — and that it's
   used for app functionality, not tracking. Be honest and minimal.
7. **Screenshots**: required for 6.7" and 6.5"/6.9" iPhone sizes. Capture from a
   real device or Simulator (run the app, ⌘S in Simulator). Write the
   description, keywords, and "what's new".

## E. Build, upload, test, submit [YOU]

1. Open **`app/ios/The Evangelist.xcworkspace`** in Xcode (the workspace, not the
   project — CocoaPods).
2. Set the run target to **Any iOS Device (arm64)**. In **Signing &
   Capabilities**, select your team and confirm Sign in with Apple is listed.
3. **Product → Archive** → Organizer → **Validate App** → **Distribute App →
   App Store Connect → Upload**.
   (Or `flutter build ipa` then upload `build/ios/ipa/*.ipa` via the Transporter
   app.)
4. **TestFlight**: once the build processes, install via TestFlight on your own
   phone and a few testers. Fix anything, re-upload.
5. **Submit for review**:
   - Attach the build, finalize screenshots/description, set price **Free**.
   - **Review notes**: explain the location feature in one line. For the reviewer,
     either provide a **demo email/password** account, or note "the app opens as a
     guest with no login required; account creation is optional."
   - Answer export compliance (already declared in Info.plist → it won't re-ask).
   - **Add for Review → Submit**. Review is typically 1–3 days.

---

## F. Pre-empt the common rejections

- ✅ Sign in with Apple present (required because social login is offered).
- ✅ In-app account deletion present.
- ✅ Location permission has a clear in-app reason and is only requested when the
  user taps "use my location".
- ⚠️ Give the reviewer a way in (demo account or the guest-mode note above).
- ⚠️ Privacy policy URL must load.
- ⚠️ Guideline 4.2 (minimum functionality): the build is a full experience — make
  sure `BACKEND_ENABLED=true` so the reviewer sees real data, not the demo stub.

---

## G. What is NOT in v1 (intentionally deferred)

- Push notifications (FCM) — `send-push` function exists but isn't wired to the
  client; no notification permission is requested.
- Google sign-in — code is present but hidden until you add the Google client IDs.
- AI follow-up drafts / daily encouragement generation (`ai-generate` function).

Add these post-launch as updates (bump `pubspec.yaml` version, re-archive,
re-upload).
