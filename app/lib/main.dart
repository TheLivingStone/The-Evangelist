import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/env.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the bundled .env asset so Env can read config at runtime. Tolerate a
  // missing file (e.g. CI passing everything via --dart-define instead).
  await dotenv.load(fileName: '.env', isOptional: true);
  // Initialise Supabase before the first frame so a persisted session is
  // restored synchronously (the auth gate relies on this). A bad/empty key
  // throws here; we catch it and fall through to a friendly config screen.
  var initOk = true;
  if (Env.backendEnabled) {
    try {
      await initSupabase();
    } catch (_) {
      initOk = false;
    }
  }
  runApp(ProviderScopedApp(initOk: initOk));
}

/// The app wrapped in its ProviderScope — used by both main() and tests.
class ProviderScopedApp extends StatelessWidget {
  const ProviderScopedApp({super.key, this.initOk = true});
  final bool initOk;
  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: EvangelistApp(initOk: initOk));
}

class EvangelistApp extends ConsumerWidget {
  const EvangelistApp({super.key, this.initOk = true});
  final bool initOk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    Widget home;
    if (!Env.backendEnabled) {
      // Offline/demo mode: skip auth entirely.
      home = const HomeShell();
    } else if (!initOk) {
      home = const _MissingConfig();
    } else {
      home = const _AuthGate();
    }

    return MaterialApp(
      title: 'The Evangelist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 180),
      themeAnimationCurve: Curves.easeOutCubic,
      home: home,
    );
  }
}

/// Routes between the sign-in screen and the app based on Supabase auth state.
/// Reads the synchronous current session as a fallback so a logged-in user is
/// never shown a flash of the auth screen on cold start.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final session = auth.asData?.value.session ?? supabase.auth.currentSession;
    if (session == null) return const AuthScreen();
    return const _SignedInGate();
  }
}

/// Shown once a user is signed in. Ensures the (trigger-created) profiles row
/// is readable before handing off to the app shell.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ensureProfileProvider);
    return profile.when(
      loading: () => const _Splash(),
      error: (e, _) => _ProfileError(message: e.toString()),
      data: (_) => const HomeShell(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
  );
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Backend is enabled but Supabase is not configured.\n\nCheck '
          'SUPABASE_URL and SUPABASE_ANON_KEY in your environment.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Could not load your profile.\n\n$message',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
