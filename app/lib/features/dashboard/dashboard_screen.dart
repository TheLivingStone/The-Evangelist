import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../encouragement/encouragement_screen.dart';
import '../people/people_screen.dart';

/// Home dashboard — "Bold Refined" direction: one bold orange moment (the
/// streak hero) sitting inside a calm, spacious, hairline-bordered layout.
/// All data/providers and navigation are unchanged from the original; this is a
/// visual rebuild that composes the shared tokens in core/theme.dart.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(monthCountsProvider);
          ref.invalidate(weekDaysActiveProvider);
          ref.invalidate(dueFollowupsProvider);
          ref.invalidate(recentActivityProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Dims.l,
            Dims.s,
            Dims.l,
            96, // clear the bottom nav + FAB
          ),
          children: [
            _Greeting(profile: profile),
            const SizedBox(height: Dims.l),
            profile.when(
              data: (p) => p == null
                  ? const SizedBox.shrink()
                  : _StreakHero(profile: p),
              loading: () => const _StreakHeroSkeleton(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: Dims.m),
            const _ImpactRow(),
            const SizedBox(height: Dims.m),
            const _WeeklyMission(),
            const SizedBox(height: Dims.m),
            const _QuickActions(),
            const SizedBox(height: Dims.m),
            const _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

/// Date overline + personalised greeting, replacing the old SliverAppBar title.
class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});
  final AsyncValue<Profile?> profile;

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE · MMM d').format(DateTime.now());
    final firstName = profile.value?.fullName.trim().split(' ').first ?? '';
    final greeting = firstName.isEmpty
        ? _timeGreeting
        : '$_timeGreeting, $firstName';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Surfaces.overline(context, date),
              const SizedBox(height: 2),
              Text(
                greeting,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Dims.border(context), width: Dims.hairline),
          ),
          child: Icon(
            Icons.notifications_none_rounded,
            size: 20,
            color: Dims.muted(context),
          ),
        ),
      ],
    );
  }
}

/// The one bold moment: a solid-orange streak card with a large number.
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    // Dark, readable text on orange — coral-900 from the design palette.
    const onOrange = Color(0xFF4A1B0C);
    final subtitle = profile.lastEvangelismDate == null
        ? 'Log your first outreach to begin'
        : 'Last shared ${_ago(profile.lastEvangelismDate!)} — keep it alive';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(Dims.rLg),
      ),
      padding: const EdgeInsets.all(Dims.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.local_fire_department, size: 15, color: onOrange),
              SizedBox(width: 5),
              Text(
                'CURRENT STREAK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: onOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${profile.currentStreak}',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                  ),
                ),
                TextSpan(
                  text: profile.currentStreak == 1 ? ' day' : ' days',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12.5, color: onOrange),
          ),
        ],
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

class _StreakHeroSkeleton extends StatelessWidget {
  const _StreakHeroSkeleton();
  @override
  Widget build(BuildContext context) => Container(
    height: 116,
    decoration: BoxDecoration(
      color: AppColors.accent.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(Dims.rLg),
    ),
  );
}

/// Two big-number stat tiles in hairline cards: conversations + salvations this
/// month (the headline metrics). The full four-metric set lives lower as a
/// detail — here we surface only the two that matter most at a glance.
class _ImpactRow extends ConsumerWidget {
  const _ImpactRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(monthCountsProvider);
    return counts.when(
      data: (c) => Row(
        children: [
          Expanded(
            child: _StatTile(
              value: c['conversation'] ?? 0,
              label: 'Conversations',
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: Dims.m),
          Expanded(
            child: _StatTile(
              value: c['salvation'] ?? 0,
              label: 'Salvations',
              color: AppColors.accent2,
            ),
          ),
        ],
      ),
      loading: () => Row(
        children: const [
          Expanded(child: _StatTileSkeleton()),
          SizedBox(width: Dims.m),
          Expanded(child: _StatTileSkeleton()),
        ],
      ),
      error: (e, _) => _ErrorCard(message: '$e'),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });
  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Surfaces.card(
    context,
    padding: const EdgeInsets.all(Dims.l),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: Dims.muted(context)),
        ),
      ],
    ),
  );
}

class _StatTileSkeleton extends StatelessWidget {
  const _StatTileSkeleton();
  @override
  Widget build(BuildContext context) =>
      Surfaces.card(context, child: const SizedBox(height: 44));
}

/// Weekly goal progress in a calm hairline card.
class _WeeklyMission extends ConsumerWidget {
  const _WeeklyMission();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(weekDaysActiveProvider);
    final goal = ref.watch(myProfileProvider).value?.weeklyGoal ?? 5;
    return Surfaces.card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Weekly mission',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              days.maybeWhen(
                data: (d) => Text(
                  '$d of $goal days',
                  style: TextStyle(fontSize: 12.5, color: Dims.muted(context)),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: Dims.m),
          ClipRRect(
            borderRadius: BorderRadius.circular(Dims.s),
            child: LinearProgressIndicator(
              value: days.maybeWhen(
                data: (d) => goal == 0 ? 0.0 : (d / goal).clamp(0.0, 1.0),
                orElse: () => 0.0,
              ),
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.08),
              color: AppColors.green,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grouped action rows (encouragement + follow-ups) sharing one hairline card,
/// each with a leading icon chip — the "list inside a card" pattern from the
/// mockup.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueFollowupsProvider);
    final dueCount = due.value?.length ?? 0;
    final dueNames = (due.value ?? [])
        .take(2)
        .map((c) => c.firstName)
        .join(', ');

    return Surfaces.card(
      context,
      padding: const EdgeInsets.symmetric(horizontal: Dims.l),
      child: Column(
        children: [
          _ActionRow(
            icon: Icons.menu_book_rounded,
            tint: AppColors.accent2,
            title: 'Daily encouragement',
            subtitle: 'A word + a tiny mission for today',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EncouragementScreen()),
            ),
          ),
          Divider(height: Dims.hairline, color: Dims.border(context)),
          _ActionRow(
            icon: Icons.group_rounded,
            tint: AppColors.blue,
            title: dueCount == 0
                ? 'No follow-ups due'
                : '$dueCount follow-up${dueCount == 1 ? '' : 's'} due',
            subtitle: dueCount == 0
                ? 'You\'re all caught up 🎉'
                : (dueNames.isEmpty ? 'Tap to review' : dueNames),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PeopleScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Dims.m),
      child: Row(
        children: [
          Surfaces.iconChip(context, icon, tint),
          const SizedBox(width: Dims.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: Dims.muted(context)),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    ),
  );
}

class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentActivityProvider);
    return Surfaces.card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Dims.s),
          recent.when(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: Dims.s),
                    child: Text(
                      'Nothing yet — tap ＋ to log your first outreach.',
                      style: TextStyle(fontSize: 13, color: Dims.muted(context)),
                    ),
                  )
                : Column(
                    children: [
                      for (final a in list)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text(
                                  _emoji(a.type),
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                              const SizedBox(width: Dims.s),
                              Expanded(
                                child: Text(
                                  _label(a.type),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                _ago(a.occurredAt),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Dims.muted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Dims.s),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => _ErrorCard(message: '$e'),
          ),
        ],
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Surfaces.card(
    context,
    child: Text(
      message,
      style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5484D)),
    ),
  );
}
