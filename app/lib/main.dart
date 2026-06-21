import 'package:clerk_auth/clerk_auth.dart' as clerk;
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/clerk_web_persistor.dart';
import 'core/env.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'features/shell/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load the bundled .env asset so Env can read config at runtime. Tolerate a
  // missing file (e.g. CI passing everything via --dart-define instead).
  await dotenv.load(fileName: '.env', isOptional: true);
  if (Env.backendEnabled) await initSupabase();
  // On web, Clerk's default (path_provider-backed) persistor is unavailable,
  // so supply a SharedPreferences-backed one. On native, pass null to keep
  // Clerk's default file-based persistor.
  final clerk.Persistor? clerkPersistor = Env.backendEnabled && kIsWeb
      ? await ClerkWebPersistor.create()
      : null;
  runApp(ProviderScopedApp(clerkPersistor: clerkPersistor));
}

/// The app wrapped in its ProviderScope — used by both main() and tests.
class ProviderScopedApp extends StatelessWidget {
  const ProviderScopedApp({super.key, this.clerkPersistor});
  final clerk.Persistor? clerkPersistor;
  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: EvangelistApp(clerkPersistor: clerkPersistor));
}

class EvangelistApp extends ConsumerWidget {
  const EvangelistApp({super.key, this.clerkPersistor});
  final clerk.Persistor? clerkPersistor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    if (!Env.backendEnabled) {
      return MaterialApp(
        title: 'The Evangelist',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 180),
        themeAnimationCurve: Curves.easeOutCubic,
        home: const HomeShell(),
      );
    }

    // Misconfiguration guard: without a Clerk publishable key there is no auth.
    if (Env.clerkPublishableKey.isEmpty) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _MissingClerkKey(),
      );
    }

    // ClerkAuth must sit above everything that reads auth state. We forward the
    // active ClerkAuthState into core/supabase.dart (via _ClerkBridge) so the
    // Supabase accessToken callback and currentUserId can reach it.
    return ClerkAuth(
      // The persistor must go on the CONFIG: AuthConfig.initialize() calls
      // persistor.initialize() at startup. Clerk's default uses path_provider
      // (no web impl) and hangs the app on web; we pass a SharedPreferences-
      // backed one there. Null on native keeps Clerk's default file persistor.
      config: ClerkAuthConfig(
        publishableKey: Env.clerkPublishableKey,
        persistor: clerkPersistor,
      ),
      child: MaterialApp(
        title: 'The Evangelist',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        themeAnimationDuration: const Duration(milliseconds: 180),
        themeAnimationCurve: Curves.easeOutCubic,
        home: ClerkErrorListener(
          child: ClerkAuthBuilder(
            signedOutBuilder: (context, authState) => _ClerkBridge(
              authState: authState,
              child: const ClerkAuthentication(),
            ),
            signedInBuilder: (context, authState) => _ClerkBridge(
              authState: authState,
              child: const _SignedInGate(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Registers the current [ClerkAuthState] with core/supabase.dart and refreshes
/// Riverpod-derived data whenever Clerk's auth state changes (sign in/out swaps
/// the user, so cached per-user data must be invalidated).
class _ClerkBridge extends ConsumerStatefulWidget {
  const _ClerkBridge({required this.authState, required this.child});
  final ClerkAuthState authState;
  final Widget child;

  @override
  ConsumerState<_ClerkBridge> createState() => _ClerkBridgeState();
}

class _ClerkBridgeState extends ConsumerState<_ClerkBridge> {
  @override
  void initState() {
    super.initState();
    clerkAuth = widget.authState;
    // Providers may have read the signed-out state while MaterialApp mounted.
    // Refresh once the first Clerk state is available.
    ref.invalidate(authChangedProvider);
  }

  @override
  void didUpdateWidget(_ClerkBridge old) {
    super.didUpdateWidget(old);
    if (!identical(old.authState, widget.authState)) {
      clerkAuth = widget.authState;
      // Auth identity changed — drop any data cached for the previous user.
      ref.invalidate(authChangedProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown once Clerk reports a signed-in user. Ensures a profiles row exists
/// (created on first sign-in) before handing off to the app shell.
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

class _MissingClerkKey extends StatelessWidget {
  const _MissingClerkKey();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'Clerk is not configured.\n\nPass --dart-define=CLERK_PUBLISHABLE_KEY=pk_... '
          'when running or building the app.',
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
