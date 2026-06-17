/// Environment configuration, supplied via --dart-define at build/run time.
///
/// Example:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://ryufvbhddsntcrvpkpet.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
///
/// Defaults below point at The Evangelist's cloud project so the app runs
/// out of the box for development; override per-environment for staging/prod.
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ryufvbhddsntcrvpkpet.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_EWal_Z9h6dZxbTFbul_R7w_56v6Si0o',
  );

  /// Optional — only needed when the native Google Map is wired up.
  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
}
