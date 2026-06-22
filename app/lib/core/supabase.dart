import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Global accessor for the Supabase client. Initialised in main().
SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The configured key is a publishable key (sb_publishable_...). Supabase
    // Auth manages the session and JWT itself — no accessToken override — which
    // also turns on local session persistence (so a logged-in user is restored
    // on cold start).
    publishableKey: Env.supabaseAnonKey,
  );
}

/// The current user's id (a uuid from Supabase Auth), or null when signed out.
/// Every repository writes this as owner_id / user_id / author_id, and RLS
/// matches it against auth.uid().
String? get currentUserId => Supabase.instance.client.auth.currentUser?.id;
