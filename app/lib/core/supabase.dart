import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Global accessor for the Supabase client. Initialised in main().
SupabaseClient get supabase => Supabase.instance.client;

/// The active Clerk auth state. Identity is owned by Clerk, not Supabase Auth,
/// so the rest of the app reads the current user id and session token from here.
///
/// It is set once the [ClerkAuth] widget is mounted (see ClerkBridge in
/// main.dart). Until then it is null and the user is treated as signed out.
ClerkAuthState? _clerkAuth;
set clerkAuth(ClerkAuthState? state) => _clerkAuth = state;
ClerkAuthState? get clerkAuth => _clerkAuth;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The configured key is a publishable key (sb_publishable_...).
    publishableKey: Env.supabaseAnonKey,
    // Forward the Clerk session JWT to Supabase on every request. Supabase is
    // configured with Clerk as a third-party auth provider, so it verifies the
    // token and exposes the Clerk user id to RLS as auth.jwt()->>'sub'.
    //
    // IMPORTANT: when accessToken is supplied, the `supabase.auth` namespace
    // must not be used — sign-in/out and the current user come from Clerk.
    accessToken: _clerkAccessToken,
  );
}

/// Returns the current Clerk session JWT, or null when signed out.
/// May be called repeatedly/concurrently by the Supabase client; Clerk's
/// token cache handles memoisation and refresh.
Future<String?> _clerkAccessToken() async {
  final auth = _clerkAuth;
  if (auth == null || !auth.isSignedIn) return null;
  try {
    final token = await auth.sessionToken();
    return token.jwt;
  } on clerk.ClerkError {
    // Token unavailable (e.g. just signed out) — surface as anonymous.
    return null;
  }
}

/// The current user's Clerk id (the JWT 'sub' claim), or null when signed out.
/// This is what every repository writes as owner_id / user_id / author_id and
/// what RLS matches against auth.jwt()->>'sub'.
String? get currentUserId => _clerkAuth?.user?.id;
