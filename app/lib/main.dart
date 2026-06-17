import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'features/auth/auth_screen.dart';
import 'features/shell/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: EvangelistApp()));
}

class EvangelistApp extends ConsumerWidget {
  const EvangelistApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final auth = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'The Evangelist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: auth.when(
        loading: () => const _Splash(),
        error: (_, __) => const AuthScreen(),
        data: (state) {
          final loggedIn = supabase.auth.currentSession != null;
          return loggedIn ? const HomeShell() : const AuthScreen();
        },
      ),
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
