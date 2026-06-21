import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../encouragement/encouragement_screen.dart';
import '../people/people_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(monthCountsProvider);
          ref.invalidate(weekDaysActiveProvider);
          ref.invalidate(dueFollowupsProvider);
          ref.invalidate(recentActivityProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              title: profile.when(
                data: (p) =>
                    Text('Hi, ${p?.fullName.split(' ').first ?? ''} 👋'),
                loading: () => const Text('…'),
                error: (_, _) => const Text('The Evangelist'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  profile.when(
                    data: (p) => p == null
                        ? const SizedBox.shrink()
                        : _StreakCard(profile: p),
                    loading: () => const _LoadingCard(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 16),
                  const _WeeklyMission(),
                  const SizedBox(height: 16),
                  const _ImpactGrid(),
                  const SizedBox(height: 16),
                  const _FollowupReminders(),
                  const SizedBox(height: 16),
                  const _DailyEncouragementCard(),
                  const SizedBox(height: 16),
                  const _RecentActivity(),
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const Card(
    child: SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
    ),
  );
}

class _StreakCard extends StatelessWidget {
  final Profile profile;
  const _StreakCard({required this.profile});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.18),
              AppColors.accent2.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 44)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.currentStreak} day streak',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    profile.lastEvangelismDate == null
                        ? 'Log your first outreach to start your streak'
                        : 'Last shared ${_ago(profile.lastEvangelismDate!)}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d).inDays;
    if (diff <= 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }
}

class _WeeklyMission extends ConsumerWidget {
  const _WeeklyMission();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weekDaysActiveProvider);
    final profile = ref.watch(myProfileProvider).value;
    final goal = profile?.weeklyGoal ?? 5;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Mission',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Share the Gospel $goal days this week',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 14),
            days.when(
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: goal == 0 ? 0 : (d / goal).clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('$d / $goal days'),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('—'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpactGrid extends ConsumerWidget {
  const _ImpactGrid();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(monthCountsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Impact This Month',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 14),
            counts.when(
              data: (c) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.0,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _stat(
                    'Conversations',
                    c['conversation'] ?? 0,
                    AppColors.green,
                  ),
                  _stat('Salvations', c['salvation'] ?? 0, AppColors.accent),
                  _stat('Follow-Ups', c['followup'] ?? 0, AppColors.blue),
                  _stat(
                    'Church Connections',
                    c['church_connection'] ?? 0,
                    AppColors.purple,
                  ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

class _FollowupReminders extends ConsumerWidget {
  const _FollowupReminders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueFollowupsProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Follow-Up Reminders',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PeopleScreen()),
                  ),
                  child: const Text('View all'),
                ),
              ],
            ),
            due.when(
              data: (list) => list.isEmpty
                  ? Text(
                      'No one is due today. 🎉',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : Column(
                      children: list
                          .map(
                            (c) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.accent.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(c.firstName.characters.first),
                              ),
                              title: Text(c.displayName),
                              subtitle: Text(prettyStatus(c.status)),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyEncouragementCard extends StatelessWidget {
  const _DailyEncouragementCard();
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Text('📖', style: TextStyle(fontSize: 28)),
        title: const Text(
          'Daily Encouragement',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('A word + a tiny mission for today'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EncouragementScreen()),
        ),
      ),
    );
  }
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentActivityProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 8),
            recent.when(
              data: (list) => list.isEmpty
                  ? Text(
                      'Nothing yet — tap ➕ to log your first outreach.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    )
                  : Column(
                      children: list
                          .map(
                            (a) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Text(
                                _emoji(a.type),
                                style: const TextStyle(fontSize: 20),
                              ),
                              title: Text(_label(a.type)),
                              subtitle: Text(_ago(a.occurredAt)),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  String _emoji(String t) => switch (t) {
    'conversation' => '💬',
    'salvation' => '✝️',
    'prayer' => '🙏',
    'followup' => '📩',
    'church_connection' => '⛪',
    _ => '•',
  };
  String _label(String t) => switch (t) {
    'conversation' => 'Gospel conversation',
    'salvation' => 'Salvation recorded',
    'prayer' => 'Prayer',
    'followup' => 'Follow-up',
    'church_connection' => 'Church connection',
    _ => t,
  };
  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
