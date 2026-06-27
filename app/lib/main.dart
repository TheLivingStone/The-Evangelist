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
      // Login is disabled for now: if no session was restored, sign in
      // anonymously so the user lands straight in the app. Every screen relies
      // on a non-null auth user id (RLS + currentUserId), so an anonymous user
      // keeps all of that working without showing a sign-in screen. A failure
      // here is non-fatal — the auth gate still shows AuthScreen as a fallback.
      if (supabase.auth.currentSession == null) {
        try {
          // Seed a placeholder full_name: the handle_new_user trigger copies it
          // into profiles.full_name, which is NOT NULL. Anonymous users have no
          // real name yet, so without this the profile insert would fail.
          await supabase.auth.signInAnonymously(
            data: {'full_name': 'Guest'},
          );
        } catch (_) {
          // Most likely Anonymous sign-ins aren't enabled on the Supabase
          // project yet (Authentication → Providers → Anonymous). Fall through;
          // the auth gate will surface the normal sign-in screen.
        }
      }
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
      // Honor the user's Dynamic Type setting, but clamp the upper end so the
      // largest accessibility sizes don't overflow fixed-height rows (e.g. the
      // bottom nav). 1.0 floor keeps small text from shrinking below design.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
      // A real account that can't load its profile is a genuine error worth
      // surfacing. But a guest (anonymous) must never be trapped on an error
      // screen — the whole point is the app opens for them — so fall through to
      // the shell; gated actions will prompt them to create an account.
      error: (e, _) => supabase.auth.currentUser?.isAnonymous == true
          ? const HomeShell()
          : _ProfileError(message: e.toString()),
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
