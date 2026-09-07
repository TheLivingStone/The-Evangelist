import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_account.dart';
import '../../core/glass.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../people/people_screen.dart';
import '../people/add_person_screen.dart';
import '../sessions/session_live_screen.dart';
import '../community/composer_screen.dart';
import '../../core/coach_marks.dart';

/// The ➕ Start "What happened today?" movement sheet — the core action.
class StartSheet extends ConsumerWidget {
  const StartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      CoachMarks.show(
        context,
        id: 'log',
        target: CoachTargets.logConversation,
        text:
            'One tap logs a Gospel conversation to your record and streak. '
            'Prayers and new people work the same way.',
      );
    });
    return GlassSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What happened today?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _action(
            context,
            Icons.play_circle_fill,
            AppColors.accent,
            'Start Outreach Session',
            'Begin a timed session',
            () async {
              if (!await requireAccount(context, ref)) return;
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              // This sheet is unmounted the moment we navigate away, and
              // Riverpod 3 throws if `ref` is touched after that. Grab the
              // container now and use it for everything that follows.
              final container = ProviderScope.containerOf(context);
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const _StartingSessionScreen(),
                ),
              );
              try {
                final session = await container
                    .read(sessionsRepoProvider)
                    .start();
                container.invalidate(liveSessionProvider);
                navigator.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => SessionLiveScreen(session: session),
                  ),
                );
              } catch (error) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not start session: $error')),
                );
              }
            },
          ),
          _action(
            context,
            Icons.person_add,
            AppColors.blue,
            'Add Person',
            'Save someone you met',
            () async {
              if (!await requireAccount(context, ref)) return;
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(builder: (_) => const AddPersonScreen()),
              );
            },
          ),
          KeyedSubtree(
            key: CoachTargets.logConversation,
            child: _action(
              context,
              Icons.chat_bubble,
              AppColors.green,
              'Log Conversation',
              'Quick log a Gospel conversation',
              () async {
                await _quickLog(
                  context,
                  ref,
                  'conversation',
                  'Conversation logged',
                );
              },
            ),
          ),
          _action(
            context,
            Icons.volunteer_activism,
            AppColors.purple,
            'Log Prayer',
            'You prayed with someone',
            () async {
              await _quickLog(context, ref, 'prayer', 'Prayer logged');
            },
          ),
          _action(
            context,
            Icons.auto_awesome,
            AppColors.pink,
            'Create Testimony Post',
            'Share what God did',
            () async {
              if (!await requireAccount(context, ref)) return;
              if (!context.mounted) return;
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(builder: (_) => const ComposerScreen()),
              );
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const PeopleScreen()),
                );
              },
              icon: const Icon(Icons.people_outline),
              label: const Text('My People'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickLog(
    BuildContext context,
    WidgetRef ref,
    String type,
    String msg,
  ) async {
    if (!await requireAccount(context, ref)) return;
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Popping the sheet unmounts this widget; Riverpod 3 throws on any `ref`
    // use after that, so hold the container instead (see Start Session above).
    final container = ProviderScope.containerOf(context);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving activity...'),
        duration: Duration(days: 1),
      ),
    );
    try {
      final live = await container.read(sessionsRepoProvider).live();
      await container.read(activityRepoProvider).log(type, sessionId: live?.id);
      container.invalidate(myProfileProvider);
      container.invalidate(monthCountsProvider);
      container.invalidate(recentActivityProvider);
      container.invalidate(weekDaysActiveProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text('$msg - keep going!')));
    } catch (error) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save activity: $error')),
      );
    }
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartingSessionScreen extends StatelessWidget {
  const _StartingSessionScreen();

  @override
  Widget build(BuildContext context) {
    return const PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                'Starting outreach...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
