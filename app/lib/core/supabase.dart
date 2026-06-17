import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Global accessor for the Supabase client. Initialised in main().
SupabaseClient get supabase => Supabase.instance.client;

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The configured key is a publishable key (sb_publishable_...).
    anonKey: Env.supabaseAnonKey,
  );
}

String? get currentUserId => supabase.auth.currentUser?.id;
