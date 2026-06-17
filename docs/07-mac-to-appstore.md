# 07 · From Your Mac to the App Store (AI-assisted build)

A practical, start-to-finish guide to building **The Evangelist** on your Mac — with heavy AI assistance — and getting it published on Apple's App Store. Written for someone who isn't a full-time developer but is comfortable following steps and using an AI coding tool.

> The short version: install the tools → let an AI coding assistant build the Flutter app from the docs in this repo → test it on your iPhone → enrol in the Apple Developer Program ($99/year) → upload from Xcode → test via TestFlight → submit for review. Plan for **a few weeks of building** and **1–3 days for Apple's review** once you submit.

---

## 0. What you'll need

| Thing | Cost | Notes |
|-------|------|-------|
| A Mac | already have | macOS is **required** to build and submit iOS apps |
| Xcode | free | Apple's build tool, from the Mac App Store (large download, ~10–15 GB) |
| Flutter SDK | free | the framework the app is built in |
| An AI coding tool | free–$20/mo | **Cursor** or **Claude Code** (recommended) to do the actual coding with you |
| Apple Developer Program | **$99/year** | required to publish; enrol when you're ready to ship |
| Supabase | free to start | your backend (already documented in this repo) |
| Google Maps API key | free tier | for the live map |
| Firebase project (FCM) | free | for push notifications |
| AI API key (Claude/OpenAI) | usage-based | for follow-up drafts & daily encouragement |
| An iPhone | already have | to test on a real device |

---

## 1. Set up your Mac for development

Open the **Terminal** app (Applications → Utilities → Terminal) and run these one at a time.

**1.1 Install Xcode** — get it from the Mac App Store (search "Xcode", Install). Then accept the licence and install components:
```bash
sudo xcodebuild -license accept
xcode-select --install
```

**1.2 Install Homebrew** (a package manager that makes the rest easy):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**1.3 Install Flutter + CocoaPods:**
```bash
brew install --cask flutter
brew install cocoapods
```

**1.4 Install an AI code editor** — download **Cursor** (cursor.com) or use **Claude Code**. This is what you'll build the app *with*.

**1.5 Verify everything:**
```bash
flutter doctor
```
Work through anything it flags with a ✗ (usually "accept Android licences" or "install Xcode components"). When the iOS line shows a ✓, you're ready. (Android tooling is optional now — you can add it later for the Google Play version.)

---

## 2. Stand up the backend (Supabase)

You can do this before or alongside the app — the app needs it to run.

1. Create a free account at supabase.com and make a new project (pick a region near your users; save the database password).
2. In the project's **SQL Editor**, paste and run **`/supabase/schema.sql`**, then **`/supabase/policies.sql`** (in that order).
3. Enable the **PostGIS** and **pg_cron** extensions (Database → Extensions) if the schema didn't already.
4. From **Project Settings → API**, copy your **Project URL** and **anon public key** — you'll give these to the app.

That's a working, secured backend. (See `03-security-rls.md` and `04-backend-logic.md` for the Edge Functions and scheduled jobs you'll add later.)

---

## 3. Build the app with AI

This is where the AI coding tool does the heavy lifting. Open the project folder (this repo) in **Cursor** or **Claude Code** so the AI can see the `/docs` and `/supabase` files — they are written to be its instructions.

**3.1 Scaffold the project:**
```bash
flutter create the_evangelist
cd the_evangelist
```

**3.2 Point the AI at the docs.** Give it a prompt like:
> "You're building a Flutter app called The Evangelist. The full spec is in `/docs` — read `00-overview.md`, `01-architecture.md`, `02-data-model.md`, `03-security-rls.md`, `04-backend-logic.md`, and `05-feature-specs.md`. Use Supabase (`supabase_flutter`), Riverpod for state, and the folder structure in `01-architecture.md`. Start by setting up the Supabase client, theme (dark default with a light toggle), and the 5-tab navigation (Dashboard · Community · ➕ Start · Map · Profile). Then build the Dashboard screen exactly as described in `05-feature-specs.md` and the prototype."

**3.3 Build screen by screen.** Don't ask for the whole app at once. Work in the order the core loop matters: **Auth → Dashboard → ➕ Start sheet → Log/Add Person → Community feed → Live Map → Profile.** After each screen, run the app and check it before moving on.

**3.4 Feed it the prototype.** Open `prototype.html` for visual reference and tell the AI "match this look." The prototype is your design source of truth.

**3.5 Add the keys.** Store your Supabase URL/anon key, Google Maps key, and so on via `--dart-define` (never hard-code them). The AI can wire this up; just keep secrets out of the code that gets committed.

**3.6 Run it:**
```bash
open -a Simulator          # launches the iOS Simulator
flutter run                # runs the app on the simulator
```

**Tips for AI-assisted building:** keep changes small and test often; paste exact error messages back to the AI; commit working versions with `git` so you can always roll back; ask the AI to explain anything you don't understand.

---

## 4. Test on your own iPhone

1. Plug your iPhone into the Mac with a cable; trust the computer.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. In **Signing & Capabilities**, sign in with your Apple ID and let Xcode manage signing (a free Apple ID works for testing on your own device; publishing needs the paid program).
4. Pick your iPhone as the run target and press ▶. The app installs on your phone.

Use this loop to feel the real app on a device before you spend anything on Apple's program.

---

## 5. Get the app release-ready

Before Apple will accept it, the app needs these. The AI can help with each:

- **App name & bundle ID** — e.g. name "The Evangelist", bundle ID like `com.yourname.theevangelist` (must be unique and permanent).
- **App icon** — a 1024×1024 icon plus all sizes. Use the `flutter_launcher_icons` package to generate them from one image.
- **Version & build number** — set in `pubspec.yaml` (e.g. `1.0.0+1`).
- **Permission strings** (in `ios/Runner/Info.plist`) — Apple **rejects** apps that ask for access without a clear reason. You need:
  - Location ("Show you on the live map and find evangelists and churches nearby.")
  - Camera/Photos ("Add a photo to a contact or an outreach post.")
  - Notifications ("Remind you about follow-ups and keep your streak.")
- **Sign in with Apple** — **required** by Apple because you offer Google sign-in. Add it.
- **Privacy policy** — a public URL is **mandatory**, especially because the app uses location. (A simple hosted page is fine.)
- **Account deletion** — Apple requires in-app account deletion if you have accounts. The schema's `on delete cascade` makes this clean.

---

## 6. Enrol in the Apple Developer Program

When you're ready to publish (not before — it's an annual fee):

1. Go to developer.apple.com → **Account** → **Enroll**.
2. Choose **Individual** (fastest, approval typically **1–3 days**) or **Organization** (needs a legal entity / D-U-N-S number, **7+ days**). For a solo project, Individual is simplest; your name shows as the seller.
3. Pay the **$99/year** fee. Non-profits, schools, and government entities can apply for a **fee waiver**.

---

## 7. Create the app in App Store Connect

App Store Connect (appstoreconnect.apple.com) is Apple's web dashboard for your app.

1. Register your **bundle ID** at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.
2. In App Store Connect → **My Apps → + → New App**: choose iOS, your app name, primary language, the bundle ID, and an **SKU** (any internal code, e.g. `evangelist-001`).
3. Fill in **App Information**: category (Lifestyle or Reference), subtitle, and your privacy policy URL.
4. Complete the **Privacy "nutrition labels"** (App Privacy section) — declare that you collect contacts you enter, location, and account data, and how each is used. Be honest and minimal (matches your privacy principles).
5. Prepare **screenshots** (required) for the listed iPhone sizes — you can take these from the Simulator (`flutter run` then ⌘S), or polish them in a tool. Write a compelling **description**, keywords, and what's-new text.

---

## 8. Upload your build from the Mac

Two ways — both start by building a release version:

**Option A — Xcode (most visual):**
1. In Xcode, set the run target to **Any iOS Device (arm64)**.
2. **Product → Archive**. When it finishes, the **Organizer** window opens.
3. Select the archive → **Validate App** (catches problems early) → then **Distribute App → App Store Connect → Upload**.

**Option B — command line + Transporter:**
```bash
flutter build ipa
```
Then open the **Transporter** app (free, Mac App Store), drag in the generated `.ipa` from `build/ios/ipa/`, and **Deliver**.

Either way, within ~30 minutes Apple emails you that the build is processed and available in App Store Connect.

---

## 9. Beta test with TestFlight

1. In App Store Connect → your app → **TestFlight**.
2. **Internal testing:** add yourself and up to ~100 team testers (App Store Connect users) — available almost immediately, no review.
3. **External testing:** invite up to 10,000 testers by email or a public link — this requires a quick "beta app review" first.
4. Testers install the **TestFlight** app and run your build on their phones. Gather feedback, fix, upload a new build, repeat.

Do a real TestFlight round with a handful of evangelists before going public — it's the single best way to catch issues.

---

## 10. Submit for review and release

1. In App Store Connect → your app → the version page, attach the build, finalise screenshots/description, set pricing (Free), and answer the export-compliance and content questions.
2. Add **Review Notes** with a **demo account** (Apple's reviewer must be able to log in) and a one-line explanation of the location feature.
3. Click **Add for Review → Submit**.
4. Review typically takes **1–3 days**. If approved, you can release immediately or schedule it. If rejected, Apple tells you why in the Resolution Center — fix and resubmit (this is normal; don't be discouraged).

**Common rejection reasons to pre-empt:**
- Missing **Sign in with Apple** when other social logins exist.
- **Location permission** without a clear in-app reason, or requesting it before it's needed.
- No working **demo login** for the reviewer.
- Missing/invalid **privacy policy** URL.
- Guideline **4.2 "minimum functionality"** — make sure the build is a complete, polished experience, not a thin shell.

---

## 11. Timeline & cost summary

| Phase | Time | Cost |
|-------|------|------|
| Mac setup | a few hours | free |
| Backend (Supabase) | 1–2 hours | free tier |
| Build the MVP with AI | a few weeks (part-time) | free–$20/mo (AI tool) |
| Apple Developer enrolment | 1–3 days approval | $99/year |
| App Store Connect setup + assets | half a day | free |
| TestFlight beta | 1–2 weeks of feedback | free |
| App review | 1–3 days | free |
| **First public release** | **~1–2 months realistic** | **~$99 + small usage** |

---

## 12. After launch

- Push updates by bumping the version in `pubspec.yaml`, archiving, and uploading a new build (same process).
- Watch crash reports and analytics; fix fast, ship often.
- The **Android / Google Play** version ships from the *same* Flutter code — a separate ($25 one-time) developer account and a similar upload flow. Tackle it after iOS is stable.

---

### Sources
- Apple Developer Program enrolment & fee — https://developer.apple.com/help/account/membership/program-enrollment/
- Flutter "Build and release an iOS app" — https://docs.flutter.dev/deployment/ios
