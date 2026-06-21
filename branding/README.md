# Branding — App Icon

The Evangelist's app icon, ready to become the real home-screen icon on **iOS and Android** from one Flutter command.

## Files in this folder

| File | Size | Use |
|------|------|-----|
| `app_icon.png` | 1024×1024, no transparency | **iOS** app icon master (full-bleed; Apple rounds the corners itself) |
| `app_icon_foreground.png` | 1024×1024, transparent | **Android adaptive** icon foreground (the bolt, padded into the safe zone) |
| `app_icon_background.png` | 1024×1024, solid `#0A0A0C` | Android adaptive background (or just use the colour below) |
| `notification_icon.png` | 1024×1024, white silhouette | Android status-bar notification icon (must be single-colour) |
| `app_icon_preview.png` | — | How it looks masked on iOS + Android (reference only, don't ship) |

> Source of truth: `../The Evangelist Logo Designs/APP_Logo.png`. Regenerate the masters from it if the logo changes.

## Make it the app icon (Flutter)

The standard tool is **`flutter_launcher_icons`**, which generates every required size for both platforms from these masters.

**1. Copy this folder's PNGs** into your Flutter project (e.g. into `assets/branding/`).

**2. Add to `pubspec.yaml`:**
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.1

flutter_launcher_icons:
  ios: true
  android: true
  image_path: "assets/branding/app_icon.png"          # iOS master (no alpha)
  remove_alpha_ios: true                               # Apple rejects alpha in icons
  min_sdk_android: 23
  adaptive_icon_background: "#0A0A0C"                   # brand black
  adaptive_icon_foreground: "assets/branding/app_icon_foreground.png"
  # optional Android 13+ themed/monochrome icon:
  adaptive_icon_monochrome: "assets/branding/notification_icon.png"
```

**3. Generate the icons:**
```bash
flutter pub get
dart run flutter_launcher_icons
```

That writes the iOS `AppIcon.appiconset` and the Android `mipmap` / adaptive-icon resources. Rebuild the app and the bolt is your home-screen icon on both platforms.

## Notes

- **iOS** needs the icon with **no transparency and square** — `app_icon.png` already is; `remove_alpha_ios: true` is a safety net.
- **Android adaptive** icons get masked into circles/squircles by the launcher, so the bolt sits at ~60% with padding (the safe zone) and the black background fills the rest.
- **Notification icon** (Android) must be a flat single-colour silhouette with transparency — `notification_icon.png` covers it. Point `flutter_local_notifications` / FCM at it.
- After generating, do a quick check on a real device at small sizes — the preview shows it stays legible down to ~40–60px.
