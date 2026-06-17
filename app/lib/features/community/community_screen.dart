import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'composer_screen.dart';
import '../map/map_screen.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  static const _filters = [null, 'testimony', 'outreach', 'prayer', null];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.accent,
          indicatorColor: AppColors.accent,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Testimonies'),
            Tab(text: 'Outreach'),
            Tab(text: 'Prayer'),
            Tab(text: 'Nearby'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'composeFab',
        backgroundColor: AppColors.accent,
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ComposerScreen())),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _FeedList(type: _filters[0]),
          _FeedList(type: _filters[1]),
          _FeedList(type: _filters[2]),
          _FeedList(type: _filters[3]),
          const MapScreen(embedded: true),
        ],
      ),
    );
  }
}

class _FeedList extends ConsumerWidget {
  final String? type;
  const _FeedList({this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider(type));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(feedProvider(type)),
      child: feed.when(
        data: (posts) => posts.isEmpty
            ? ListView(children: const [
                SizedBox(height: 120),
                Center(
                    child: Text('No posts yet — be the first to share. ✨')),
              ])
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (_, i) => PostCard(post: posts[i], type: type),
              ),
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  final Post post;
  final String? type;
  const PostCard({super.key, required this.post, this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = post.author?.fullName ?? 'Evangelist';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  child: Text(name.characters.first),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          post.author?.church,
                          post.city ?? post.author?.city,
                        ].where((e) => e != null && e.isNotEmpty).join(' · '),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(type: post.type),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.body),
            const SizedBox(height: 12),
            Row(
              children: [
                _ReactionChip(
                  emoji: '🔥',
                  label: 'Encouraged',
                  count: post.reactionCounts['encouraged'] ?? 0,
                  active: post.myReactions.contains('encouraged'),
                  onTap: () => _react(ref, 'encouraged'),
                ),
                const SizedBox(width: 8),
                _ReactionChip(
                  emoji: '🙏',
                  label: 'Praying',
                  count: post.reactionCounts['praying'] ?? 0,
                  active: post.myReactions.contains('praying'),
                  onTap: () => _react(ref, 'praying'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _react(WidgetRef ref, String reaction) async {
    final on = !post.myReactions.contains(reaction);
    await ref.read(feedRepoProvider).toggleReaction(post.id, reaction, on);
    ref.invalidate(feedProvider(type));
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'testimony' => ('Testimony', AppColors.accent),
      'outreach' => ('Outreach', AppColors.green),
      'prayer' => ('Prayer', AppColors.purple),
      'salvation' => ('Salvation', AppColors.pink),
      _ => ('Update', AppColors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _ReactionChip({
    required this.emoji,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.18)
              : Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$emoji $label${count > 0 ? ' $count' : ''}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
