import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/env.dart';
import '../../core/providers.dart';
import '../../core/supabase.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final achievements = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: Env.backendEnabled
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  // Sign out of Supabase Auth. The auth gate in main.dart reacts
                  // to the state change and swaps back to the sign-in screen.
                  onPressed: () async => supabase.auth.signOut(),
                ),
              ]
            : null,
      ),
      body: profile.when(
        data: (p) => p == null
            ? const Center(child: Text('No profile'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                      child: Text(
                        p.fullName.characters.first,
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      p.fullName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      [
                        p.church,
                        p.city,
                      ].where((e) => e != null && e.isNotEmpty).join(' · '),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lifetime Impact',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 2.4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            children: [
                              _stat(
                                'Conversations',
                                p.totalConversations,
                                AppColors.green,
                              ),
                              _stat(
                                'Salvations',
                                p.totalSalvations,
                                AppColors.accent,
                              ),
                              _stat(
                                'Follow-Ups',
                                p.totalFollowups,
                                AppColors.blue,
                              ),
                              _stat(
                                'Church Connections',
                                p.totalChurchConnections,
                                AppColors.purple,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _miniStat(
                                  '🔥 Current streak',
                                  '${p.currentStreak} days',
                                ),
                              ),
                              Expanded(
                                child: _miniStat(
                                  '🏅 Longest streak',
                                  '${p.longestStreak} days',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Achievements',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          achievements.when(
                            data: (list) => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: list.map((a) => _badge(a)).toList(),
                            ),
                            loading: () => const LinearProgressIndicator(),
                            error: (e, _) => Text('Error: $e'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(profile: p),
                ],
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );

  Widget _miniStat(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _badge(Achievement a) => Opacity(
    opacity: a.earned ? 1 : 0.35,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: a.earned
                ? AppColors.accent.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(a.icon ?? '🏆', style: const TextStyle(fontSize: 28)),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(
            a.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends ConsumerStatefulWidget {
  final Profile profile;
  const _SettingsCard({required this.profile});

  @override
  ConsumerState<_SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends ConsumerState<_SettingsCard> {
  late bool _dark = widget.profile.theme == 'dark';
  late bool _visible = widget.profile.isVisibleOnMap;
  late bool _reminders = widget.profile.dailyReminderEnabled;
  final _saving = <String>{};

  @override
  void didUpdateWidget(_SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_saving.contains('theme')) _dark = widget.profile.theme == 'dark';
    if (!_saving.contains('is_visible_on_map')) {
      _visible = widget.profile.isVisibleOnMap;
    }
    if (!_saving.contains('daily_reminder_enabled')) {
      _reminders = widget.profile.dailyReminderEnabled;
    }
  }

  Future<void> _persist({
    required String key,
    required bool value,
    required bool oldValue,
    required void Function(bool value) apply,
  }) async {
    setState(() {
      apply(value);
      _saving.add(key);
    });
    if (key == 'theme') {
      ref
          .read(themeOverrideProvider.notifier)
          .setMode(value ? ThemeMode.dark : ThemeMode.light);
    }

    try {
      await ref.read(profileRepoProvider).update({
        key: key == 'theme' ? (value ? 'dark' : 'light') : value,
      });
      ref.invalidate(myProfileProvider);
      if (key == 'theme') {
        await ref.read(myProfileProvider.future);
        ref.read(themeOverrideProvider.notifier).setMode(null);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => apply(oldValue));
      if (key == 'theme') {
        ref.read(themeOverrideProvider.notifier).setMode(null);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save setting: $error')));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Dark theme'),
              value: _dark,
              activeThumbColor: AppColors.accent,
              onChanged: _saving.contains('theme')
                  ? null
                  : (v) => _persist(
                      key: 'theme',
                      value: v,
                      oldValue: _dark,
                      apply: (value) => _dark = value,
                    ),
            ),
            SwitchListTile(
              title: const Text('Show me on the map'),
              value: _visible,
              activeThumbColor: AppColors.accent,
              onChanged: _saving.contains('is_visible_on_map')
                  ? null
                  : (v) => _persist(
                      key: 'is_visible_on_map',
                      value: v,
                      oldValue: _visible,
                      apply: (value) => _visible = value,
                    ),
            ),
            SwitchListTile(
              title: const Text('Daily reminders'),
              value: _reminders,
              activeThumbColor: AppColors.accent,
              onChanged: _saving.contains('daily_reminder_enabled')
                  ? null
                  : (v) => _persist(
                      key: 'daily_reminder_enabled',
                      value: v,
                      oldValue: _reminders,
                      apply: (value) => _reminders = value,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
