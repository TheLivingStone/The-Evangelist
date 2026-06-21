# 08 · From Your Mac to Google Play (Android)

The Android companion to `07-mac-to-appstore.md`. The same Flutter codebase that ships to iOS also ships to **Android / Google Play** — you build a different package (an **Android App Bundle**, `.aab`) and publish it through the **Google Play Console**. You can do all of this from the same Mac.

> The short version: add Android tooling to your Mac → the AI builds the same app (a few Android-specific config bits) → test on an emulator or Android phone → create a Google Play Developer account ($25 **one-time**) → sign and build an `.aab` → run a closed test → release to production. Review is usually faster than Apple's, but new personal accounts must run a **14-day closed test with 20 testers first** (see §10).

---

## 0. What you'll need (Android side)

| Thing | Cost | Notes |
|-------|------|-------|
| Android Studio | free | Installs the Android SDK, emulator, and build tools |
| Java JDK | free | Bundled with Android Studio |
| Google Play Developer account | **$25 one-time** | Lifetime, not annual (vs Apple's $99/year) |
| Google Maps **Android** API key | free tier | Separate key from the iOS one |
| Firebase `google-services.json` | free | Android FCM config file |
| An Android phone (optional) | — | The emulator works fine; a real device is a nice final check |

Everything else (the Mac, the AI coding tool, Supabase, the AI API key, your privacy policy) is shared with the iOS guide — you don't redo it.

---

## 1. Add Android tooling to your Mac

```bash
brew install --cask android-studio
```
Open Android Studio once and let it install the **Android SDK**, **platform tools**, and an **emulator image**. Then accept the SDK licences and confirm Flutter sees everything:

```bash
flutter doctor --android-licenses   # press y to accept each
flutter doctor                       # the "Android toolchain" line should be ✓
```

Create a virtual device: Android Studio → **Device Manager → Create Device** (e.g. Pixel 8, a recent system image).

---

## 2. Backend (Supabase) — already done

The Android app talks to the **same** Supabase project, schema, and policies as iOS. Reuse the same Project URL + anon key. Nothing new here.

---

## 3. Build with AI — the Android-specific bits

It's the same app from the same code. Only a few Android config items differ from iOS — ask your AI assistant to set these up:

- **App ID** — `applicationId` in `android/app/build.gradle` (e.g. `com.yourname.theevangelist`; keep it matching your iOS bundle ID for consistency).
- **Permissions** — in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>  <!-- Android 13+ runtime prompt -->
  ```
- **Google Maps (Android) key** — add a separate Maps key to the manifest (`com.google.android.geo.API_KEY`). Restrict it to your app's package + SHA-1 in Google Cloud Console.
- **Push (FCM)** — drop `google-services.json` into `android/app/` and apply the Google Services Gradle plugin. (iOS uses an APNs key instead; both are wired through Firebase Cloud Messaging.)
- **Min/target SDK** — set a modern `targetSdkVersion` (Android 15 / API 35 today; **Android 16 / API 36 is required for new apps and updates from 31 Aug 2026**). `minSdkVersion` 23–24 is a sensible floor.

Run it on the emulator (or a connected phone):
```bash
flutter run        # picks the running emulator or attached device
```

---

## 4. Test on an Android device

Emulator is enough, but to test on your own phone:
1. On the phone: **Settings → About phone → tap "Build number" 7 times** to unlock Developer options, then enable **USB debugging**.
2. Plug it into the Mac, accept the debugging prompt.
3. `flutter run` installs the app on the phone.

---

## 5. Get the Android build release-ready

- **App icon** — already prepared in `/branding`. The same `flutter_launcher_icons` setup generates Android icons (incl. adaptive icons) using `app_icon_foreground.png` (the padded bolt) over the brand-black background `#0A0A0C`, plus `notification_icon.png` for the status bar. See `/branding/README.md`.
- **Version** — same `pubspec.yaml` `version: 1.0.0+1` drives both platforms (`versionName` + `versionCode`).
- **Permission rationale** — Android shows runtime prompts; make sure the app explains *why* before requesting location, camera, and notifications (Play reviewers and users both care).
- **Privacy policy URL** — the same hosted policy you use for Apple (mandatory, especially with location).
- **Account deletion** — required by Google too; the schema's cascade deletes cover it.

### Signing: create an upload keystore

Android signs releases with a key you generate. Run once and **keep the file safe and private** (never commit it):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then tell Gradle about it. Create `android/key.properties` (git-ignored):
```
storePassword=********
keyPassword=********
keyAlias=upload
storeFile=/Users/you/upload-keystore.jks
```
And reference it from `android/app/build.gradle` in a `signingConfigs { release { ... } }` block linked to `buildTypes.release`. Your AI assistant can wire this exactly per the Flutter docs.

> **Play App Signing:** Google holds the *final* app-signing key for you; your keystore is the *upload* key. If you ever lose the upload key, Google can reset it — but back it up anyway.

---

## 6. Create your Google Play Developer account

1. Go to play.google.com/console and sign up.
2. Pay the **$25 one-time** registration fee.
3. Complete **identity verification** (government ID; personal accounts also verify name/address). Approval is usually within ~48 hours.

---

## 7. Create the app + store listing in Play Console

1. **Create app** → name, default language, app/game, free/paid.
2. **Store listing:** short + full description, app icon, **feature graphic** (1024×500), and phone screenshots (capture from the emulator).
3. **Content rating** questionnaire → generates the age rating.
4. **Data safety** form → declare every data type you collect (contacts you enter, location, account info), why, and whether it's shared. Be honest and minimal — this mirrors your privacy principles.
5. **Target audience & content**, **privacy policy URL**, **ads** declaration, and **app access** (give Google a demo login so reviewers can sign in).

---

## 8. Build and upload the App Bundle

Google requires an **Android App Bundle** (`.aab`), not an APK:

```bash
flutter build appbundle
# output: build/app/outputs/bundle/release/app-release.aab
```

Upload that `.aab` to a release in the Play Console (see testing tracks next). Google generates optimised, device-specific APKs from it automatically.

---

## 9. Testing tracks

Play Console has progressive release tracks — use them like TestFlight:

| Track | Who | Use |
|-------|-----|-----|
| **Internal testing** | up to 100 testers, instant | your own quick checks |
| **Closed testing** | invited groups | structured beta (and a requirement — see §10) |
| **Open testing** | public opt-in | wider beta before launch |
| **Production** | everyone | the live release |

---

## 10. The closed-test requirement (important for new personal accounts)

Google requires **new personal developer accounts** to run a **closed test with at least 20 testers for 14 consecutive days** before they can apply for production access. Plan for this: it effectively adds ~2 weeks to your first Android launch.

- Recruit ~20 evangelists as closed testers (email list or a Google Group).
- Keep the test active and gather feedback for the 14 days.
- Then apply for production access and submit.

(Organisation accounts and pre-existing accounts may be exempt — check your console's "Production access" page for your exact status.)

---

## 11. Submit and release to production

1. Create a **Production** release, upload the `.aab` (or promote your tested build), add release notes.
2. Choose a **staged rollout** (e.g. start at 20%) so you can halt if something's wrong.
3. Submit. Google review for new apps typically takes **a few hours to a few days** (sometimes longer for the first submission).
4. Once approved and rolled out, the app is live on Google Play.

**Common Android pitfalls to pre-empt:**
- Forgetting the **Data safety** form or mismatching it with actual data use.
- Uploading an **APK instead of an `.aab`** (Play requires the bundle).
- A debug-signed build (must be release-signed with your keystore).
- Requesting **location/notifications** without rationale, or background location without strong justification.
- Skipping the **20-tester / 14-day closed test** on a new personal account.

---

## 12. Cross-platform parity checklist

Build once, ship to both — but verify each item works on **both** iOS and Android before you call a release done:

| Area | iOS | Android |
|------|-----|---------|
| Build artifact | `.ipa` (Xcode archive) | `.aab` (`flutter build appbundle`) |
| Store | App Store Connect | Google Play Console |
| Account cost | $99 / year | $25 one-time |
| Maps key | iOS Maps key | separate Android Maps key |
| Push | APNs key (via FCM) | `google-services.json` (FCM) |
| Sign-in | **Apple Sign-In required** (+ Google) | Google sign-in (Apple optional) |
| Notifications permission | iOS prompt | Android 13+ runtime prompt (`POST_NOTIFICATIONS`) |
| Location permission strings | `Info.plist` | `AndroidManifest.xml` + runtime rationale |
| Privacy disclosure | App Privacy "nutrition labels" | Data safety form |
| Beta testing | TestFlight | Internal/Closed/Open tracks |
| First-launch gotcha | demo login + Apple Sign-In | 20-tester / 14-day closed test (new accounts) |

**Functional parity to test on both:** auth (incl. social logins), the live map + location permission, camera/photo upload, push notifications, dark/light theme, offline logging + sync, and account deletion. The shared Flutter UI means these behave the same, but always smoke-test each on a real device per platform.

---

## 13. Recommended order

Ship **iOS first** (it's the longer pole — Apple Sign-In, $99 enrolment, review), then Android from the same code. Or run them in parallel if you have the time: kick off the Android **20-tester closed test early** (since it has the 14-day clock) while iOS is in review.

---

### Sources
- Target API level requirements (Play Console Help) — https://support.google.com/googleplay/android-developer/answer/11926878
- Flutter "Build and release an Android app" — https://docs.flutter.dev/deployment/android
