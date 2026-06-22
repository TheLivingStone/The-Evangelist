import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration.
///
/// Values are resolved at runtime from the bundled `.env` asset (loaded in
/// main() via flutter_dotenv), falling back to `--dart-define` values, then to
/// the hard-coded defaults below. This lets you keep all config in `app/.env`
/// and run with a plain `flutter run` — no --dart-define flags required —
/// while still allowing per-environment overrides via --dart-define in CI.
///
/// ONLY public, client-safe values live here. Service-role / secret keys must
/// never be bundled or referenced in client code.
class Env {
  /// Reads [key] from --dart-define first, then .env, then [fallback].
  ///
  /// Build-time values must win so CI and release builds can override a local
  /// developer's bundled configuration deterministically.
  static String _read(String key, String dartDefine, String fallback) {
    if (dartDefine.isNotEmpty) return dartDefine;
    final fromDotenv = dotenv.isInitialized ? dotenv.maybeGet(key) : null;
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return fallback;
  }

  static const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _googleMapsApiKeyDefine = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );
  static const _backendEnabledDefine = String.fromEnvironment(
    'BACKEND_ENABLED',
  );
  static const _signupSourceDefine = String.fromEnvironment('SIGNUP_SOURCE');

  /// Local development is the default while the product UI is being built.
  static bool get backendEnabled =>
      _read('BACKEND_ENABLED', _backendEnabledDefine, 'false').toLowerCase() ==
      'true';

  static String get supabaseUrl => _read(
    'SUPABASE_URL',
    _supabaseUrlDefine,
    'https://ryufvbhddsntcrvpkpet.supabase.co',
  );

  static String get supabaseAnonKey => _read(
    'SUPABASE_ANON_KEY',
    _supabaseAnonKeyDefine,
    'sb_publishable_EWal_Z9h6dZxbTFbul_R7w_56v6Si0o',
  );

  /// Optional — only needed when the native Google Map is wired up.
  static String get googleMapsApiKey =>
      _read('GOOGLE_MAPS_API_KEY', _googleMapsApiKeyDefine, '');

  /// Acquisition channel recorded on a user's FIRST sign-in, powering the admin
  /// Growth dashboard's per-campaign breakdown. Ship a campaign build with
  /// `--dart-define=SIGNUP_SOURCE=instagram_ad` (or set SIGNUP_SOURCE in .env)
  /// so installs from that campaign are attributed. Defaults to 'organic'.
  static String get signupSource =>
      _read('SIGNUP_SOURCE', _signupSourceDefine, 'organic');
}
