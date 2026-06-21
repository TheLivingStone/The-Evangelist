import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../people/people_screen.dart';
import '../people/add_person_screen.dart';
import '../sessions/session_live_screen.dart';
import '../community/composer_screen.dart';

/// The ➕ Start "What happened today?" movement sheet — the core action.
class StartSheet extends ConsumerWidget {
  const StartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const _StartingSessionScreen(),
                ),
              );
              try {
                final session = await ref.read(sessionsRepoProvider).start();
                ref.invalidate(liveSessionProvider);
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
            () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(builder: (_) => const AddPersonScreen()),
              );
            },
          ),
          _action(
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
            () {
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saving activity...'),
        duration: Duration(days: 1),
      ),
    );
    try {
      final live = await ref.read(sessionsRepoProvider).live();
      await ref.read(activityRepoProvider).log(type, sessionId: live?.id);
      ref.invalidate(myProfileProvider);
      ref.invalidate(monthCountsProvider);
      ref.invalidate(recentActivityProvider);
      ref.invalidate(weekDaysActiveProvider);
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
        color: Theme.of(context).colorScheme.surface,
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
