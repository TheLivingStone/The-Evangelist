import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/env.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'features/auth/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/splash_screen.dart';

/// Cold-start stopwatch. Each stage logs `[startup] stage +ms` so a slow
/// launch can be attributed (read it in the Xcode console / `flutter run`).
final startupClock = Stopwatch()..start();
void logStartup(String stage) =>
    debugPrint('[startup] $stage +${startupClock.elapsedMilliseconds}ms');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logStartup('main');
  // Load the bundled .env asset so Env can read config at runtime. Tolerate a
  // missing file (e.g. CI passing everything via --dart-define instead).
  await dotenv.load(fileName: '.env', isOptional: true);
  logStartup('dotenv loaded');
  // Initialise Supabase before the first frame so a persisted session is
  // restored synchronously (the auth gate relies on this). A bad/empty key
  // throws here; we catch it and fall through to a friendly config screen.
  var initOk = true;
  if (Env.backendEnabled) {
    try {
      // Local only (restores a persisted session from disk) — fast. The guest
      // sign-in that needs the network happens AFTER the first frame, behind
      // the in-app splash (see _GuestBootstrap), so a slow connection shows a
      // spinner instead of the bare launch screen.
      await initSupabase();
      logStartup(
        'supabase initialised '
        '(session=${supabase.auth.currentSession != null})',
      );
    } catch (_) {
      initOk = false;
    }
  }
  runApp(ProviderScopedApp(initOk: initOk));
  WidgetsBinding.instance.addPostFrameCallback(
    (_) => logStartup('first frame'),
  );
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
      title: 'Go and Tell',
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
    if (session == null) return const _GuestBootstrap();
    return const _SignedInGate();
  }
}

/// No session on launch: create a guest (anonymous) session so the app opens
/// without a login wall. Shows the splash while the request is in flight; if
/// it fails (e.g. anonymous sign-ins disabled, offline) falls back to the
/// normal sign-in screen. Only attempted once per process so that signing out
/// lands on AuthScreen rather than silently minting another guest.
class _GuestBootstrap extends StatefulWidget {
  const _GuestBootstrap();
  @override
  State<_GuestBootstrap> createState() => _GuestBootstrapState();
}

class _GuestBootstrapState extends State<_GuestBootstrap> {
  static bool _attempted = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if (_attempted) {
      _failed = true;
      return;
    }
    _attempted = true;
    _signInAsGuest();
  }

  Future<void> _signInAsGuest() async {
    logStartup('guest sign-in start');
    try {
      // Seed a placeholder full_name: the handle_new_user trigger copies it
      // into profiles.full_name, which is NOT NULL.
      await supabase.auth.signInAnonymously(data: {'full_name': 'Guest'});
      logStartup('guest sign-in done');
      // Success: authStateProvider emits signedIn and _AuthGate swaps us out.
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) =>
      _failed ? const AuthScreen() : const _Splash();
}

/// Shown once a user is signed in. Ensures the (trigger-created) profiles row
/// is readable before handing off to the app shell.
class _SignedInGate extends ConsumerWidget {
  const _SignedInGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ensureProfileProvider);
    ref.listen(ensureProfileProvider, (_, next) {
      if (!next.isLoading) {
        logStartup(
          'profile ${next.hasError ? 'FAILED: ${next.error}' : 'loaded'}',
        );
      }
    });
    // Only gate the FIRST load. Every profile write in the app calls
    // ref.invalidate(myProfileProvider) (theme/map/reminder toggles, quick
    // logs, name edits) and that briefly puts this provider back into loading.
    // Treating that as "show the splash" unmounted the whole tab shell and
    // remounted it on the Home tab — the "toggle a switch, get thrown back to
    // Home" bug. Riverpod keeps the previous value during a reload, so once we
    // have ever had a profile we stay on the shell.
    if (profile.hasValue) return const _OnboardingGate();
    if (profile.hasError) {
      // A real account that can't load its profile is a genuine error worth
      // surfacing. But a guest (anonymous) must never be trapped on an error
      // screen — the whole point is the app opens for them — so fall through
      // to the shell; gated actions will prompt them to create an account.
      return supabase.auth.currentUser?.isAnonymous == true
          ? const HomeShell()
          : _ProfileError(message: profile.error.toString());
    }
    return const _Splash();
  }
}

/// Profile is loaded. Show first-run onboarding once (placeholder name and not
/// yet dismissed on this device), otherwise the tab shell. Keeps the previous
/// answer during reloads so profile writes never flash the splash.
class _OnboardingGate extends ConsumerWidget {
  const _OnboardingGate();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needs = ref.watch(needsOnboardingProvider);
    if (!needs.hasValue) return const _Splash();
    return needs.value == true ? const OnboardingScreen() : const HomeShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const BrandSplash();
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
