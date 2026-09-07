# Go and Tell — Submission plan

Three parts: the first submission, what to do if Apple rejects it, and how to
ship the next update. Copy-ready listing text lives in `11-app-store-listing.md`.

Current app version: **1.0.0 (build 1)** in `app/pubspec.yaml`. Every upload to
App Store Connect needs a HIGHER build number than the last one uploaded.

---

## Part A — First submission (in order)

### Before you open Xcode
1. **Commit the code.** In `~/EvangelistBuild` run `git add -A && git commit -m "v1.0.0 launch"`
   so the archive matches a known commit.
2. **Database is ready.** `migrate_church_pastor.sql` has been run. Also run the
   CJC location fix from the chat if you have not.
3. **Clean the test content.** In the admin dashboard, delete the posts by
   "Test" and "Jordan Reviewer" so the store screenshots and first users see
   real content.
4. **Host the privacy policy.** Put the text of `docs/privacy-policy.md` on a
   public web page (your website, or a free GitHub Pages / Notion page). Copy
   the URL. Apple will not accept the submission without it.
5. **Media ready in Downloads:** `GoAndTell_AppPreview_30s.mp4` (store preview),
   `GoAndTell_ReviewWalkthrough.mp4` (for the reviewer), plus 3–6 screenshots
   taken on your iPhone with the side button + volume up.

### Build and upload
6. Open **`~/EvangelistBuild/app/ios/The Evangelist.xcworkspace`** in Xcode.
7. Top bar: choose **Any iOS Device (arm64)** as the destination.
8. **Product → Archive**. Wait for the Organizer window.
9. In Organizer: **Validate App** (fixes signing issues early), then
   **Distribute App → App Store Connect → Upload**. Accept the defaults
   (automatic signing, upload symbols).
10. Wait 10–30 minutes for "processing" to finish (you get an email).

### App Store Connect (appstoreconnect.apple.com → My Apps → Go and Tell)
11. **App Information:** name *Go and Tell*, subtitle, category Lifestyle
    (secondary Social Networking), **Privacy Policy URL** from step 4.
12. **Pricing and Availability:** Free, all territories.
13. **App Privacy:** Data collected — Name, Email, Coarse Location, User
    Content, User ID. Purpose: App Functionality. Linked to user: yes.
    Tracking: no.
14. **Age Rating:** answer the questionnaire; nothing applies → 4+.
15. **iOS App → 1.0 Prepare for Submission:**
    - Previews and Screenshots → **6.9-inch iPhone**: upload the 30 s preview
      and the screenshots. (The 6.7-inch recording is accepted in this slot.)
    - Promotional Text, Description, Keywords, Support URL, Marketing URL:
      paste from `11-app-store-listing.md`.
    - **Build:** click + and pick the build you uploaded.
    - **App Review Information:** contact name, phone, email. Sign-in
      required: **No** (the app opens as a guest). Notes: paste the Review
      Notes from `11-app-store-listing.md`. **Attachment:** upload
      `GoAndTell_ReviewWalkthrough.mp4`.
    - Version Release: **Manually release this version** (you press the
      button after approval, so you control launch day).
16. **TestFlight tab** (recommended, 15 minutes): add yourself as an internal
    tester, install from the TestFlight app on your iPhone, run through the
    tour once. This is the exact binary Apple reviews.
17. Back on the version page: **Add for Review → Submit for Review**.
18. Status goes *Waiting for Review* → *In Review* → *Ready for Distribution*
    (or *Rejected*). Typical time: 1–3 days. Email arrives at each change.
19. When approved: press **Release This Version**. It is live within a few hours.

---

## Part B — If Apple rejects it

1. Read the message in **App Store Connect → App Review** (also emailed). It
   names a guideline number and usually includes a screenshot.
2. Decide which of two paths applies:
   - **Metadata-only** (screenshots, description, missing privacy URL, review
     notes): fix the fields in App Store Connect, then in the Resolution
     Center reply "Fixed" and **resubmit the same build**. No Xcode needed.
   - **Binary issue** (crash, a feature the reviewer could not use, a missing
     capability): fix the code, then follow Part C to upload a new build.
3. Reply in the **Resolution Center** thread. Be short and factual: what you
   changed, and where the reviewer can find the feature. If the reviewer
   misunderstood something, explain politely and point them at the
   walkthrough video timestamp.
4. Resubmit. Re-reviews are usually faster than the first pass.

Common first-time rejections and where we already cover them:
- **5.1.1(v) account deletion** → Profile → Delete account (shown in the
  walkthrough at ~2:28).
- **4.8 Sign in with Apple** → offered on the account sheet next to Google/email.
- **1.2 user-generated content** → report + block on every post, blocked-
  accounts list in Profile.
- **5.1.1 location purpose string** → the permission text explains the map.
- **2.1 app crashed / could not log in** → the app opens as a guest; say so in
  the notes (already in the template).

---

## Part C — Shipping the next update (every future version)

1. Make the changes, run `flutter analyze` and `flutter test`, and test on
   your phone (`flutter build ios --release` + the devicectl install, or Run
   from Xcode).
2. **Bump the version** in `app/pubspec.yaml`:
   - Bug-fix release: `1.0.1+2` (version 1.0.1, build 2).
   - Feature release: `1.1.0+3`.
   The number after `+` must always increase.
3. Commit: `git add -A && git commit -m "v1.0.1"`.
4. Xcode: Any iOS Device → **Product → Archive → Distribute → Upload**.
5. App Store Connect → your app → **+ Version** (top left) → type the new
   version number.
6. On the new version page: write **What's New**, pick the new build, keep
   or update screenshots. Nothing else needs re-entering.
7. **Submit for Review.** Same 1–3 day review. Release when approved.

Same-version re-upload (e.g. you found a bug before Apple reviewed): bump
only the build number (`1.0.0+2`), archive, upload, and on the version page
swap the build. If the old build is already in review, click **Remove from
Review** first.
