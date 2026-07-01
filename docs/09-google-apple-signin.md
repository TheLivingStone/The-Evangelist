# Google + Apple sign-in — setup runbook

The app code is done and builds. Native Google sign-in and Sign in with Apple
are wired through Supabase `signInWithIdToken`. What remains is **account
configuration** that only you can do (it needs your Google, Supabase, and Apple
accounts). Do these steps and the buttons work end-to-end.

Your values, pre-filled:

| Thing | Value |
|---|---|
| Bundle ID | `com.theevangelist.theEvangelist` |
| Apple Team ID | `H98HSZ7HSS` |
| Supabase project ref | `ryufvbhddsntcrvpkpet` |
| Supabase callback URL | `https://ryufvbhddsntcrvpkpet.supabase.co/auth/v1/callback` |

---

## Part A — Google sign-in

### A1. Google Cloud Console — create OAuth clients
1. Go to <https://console.cloud.google.com> → create (or pick) a project.
2. **APIs & Services → OAuth consent screen**: configure it (External, app name
   "The Evangelist", your support email). Add yourself as a test user while in
   testing, or publish it.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**,
   make **two** clients:
   - **iOS** client → Bundle ID `com.theevangelist.theEvangelist`. Copy its
     **iOS client ID** (looks like `1234567890-abc123.apps.googleusercontent.com`).
   - **Web application** client → copy its **client ID and client secret**.
     (Supabase needs a *web* client; the iOS client alone is not enough.)

### A2. Supabase — enable Google
1. Dashboard → your project → **Authentication → Sign In / Providers → Google**.
2. Toggle **Enabled**. Paste the **Web** client ID into "Client ID" and the
   **Web** client secret into "Client Secret". Save.
3. The Supabase callback URL is already correct
   (`…/auth/v1/callback`) — but in Google Cloud, on the **Web** client, add that
   URL under **Authorized redirect URIs**.

### A3. App config — fill in the two client IDs
In `app/.env` set:
```
GOOGLE_IOS_CLIENT_ID=<your iOS client ID>
GOOGLE_WEB_CLIENT_ID=<your Web client ID>
```
> The Google button stays hidden until BOTH are set — that's intentional, so a
> build without them still ships with email + Apple.

### A4. iOS — register the reversed-client-ID URL scheme
The native picker returns to the app via a URL scheme = the iOS client ID with
its dot-segments reversed.

Take your iOS client ID, e.g. `1234567890-abc123.apps.googleusercontent.com`,
and reverse it to `com.googleusercontent.apps.1234567890-abc123`.

Open `app/ios/Runner/Info.plist`, find the `CFBundleURLSchemes` placeholder
(`com.googleusercontent.apps.REPLACE_WITH_REVERSED_IOS_CLIENT_ID`) and replace it
with that reversed value.

---

## Part B — Sign in with Apple (required by App Store 4.8)

### B1. Apple Developer portal — enable the capability
1. <https://developer.apple.com/account> → **Certificates, IDs & Profiles →
   Identifiers** → your App ID (`com.theevangelist.theEvangelist`).
2. Check **Sign In with Apple** → Save. (If it forces a new provisioning profile,
   let Xcode regenerate it via automatic signing — already on.)

The Xcode entitlement is already in the repo
(`app/ios/Runner/Runner.entitlements`, wired into all 3 build configs), so you do
NOT need to add it in Xcode manually — just enabling it on the App ID is enough.

### B2. Supabase — enable Apple
1. Dashboard → **Authentication → Sign In / Providers → Apple** → Enable.
2. For the **native iOS** flow (what this app uses), add the app's Bundle ID
   `com.theevangelist.theEvangelist` to the provider's **authorized client IDs /
   Services** field. (The full Services-ID + key flow is only needed for the
   *web* Apple flow, which we don't use on iOS.)
3. Save.

---

## Part C — verify on a real device
Apple/Google native sign-in **cannot be tested on the iOS Simulator reliably** —
use a physical iPhone.

```
cd app
flutter run --release        # on a connected iPhone
```
- Tap **Continue with Apple** → system sheet → should land in the app.
- Tap **Continue with Google** → native account picker → should land in the app.
- New users appear in Supabase → Authentication → Users, and the
  `handle_new_user` trigger creates their `profiles` row.

## Troubleshooting
- **Google button missing** → one of the two `GOOGLE_*_CLIENT_ID` values in
  `.env` is empty. Both required.
- **Google opens then returns to the login screen / errors** → the reversed URL
  scheme in Info.plist doesn't match the iOS client ID, or Supabase has the wrong
  (non-web) client ID/secret.
- **"audience" / token rejected by Supabase** → `GOOGLE_WEB_CLIENT_ID` must be
  the *Web* client, and the same client must be configured in Supabase.
- **Apple "not handled" / capability error** → Sign In with Apple isn't enabled
  on the App ID (step B1), or the bundle ID isn't in Supabase's Apple provider
  (step B2).
