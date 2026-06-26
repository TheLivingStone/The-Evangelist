import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_account.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'composer_screen.dart';
import 'post_detail_screen.dart';
import 'post_photo.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(allFeedProvider.future).ignore();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ComposerScreen()),
        ),
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
      onRefresh: () async {
        ref.invalidate(allFeedProvider);
        await ref.read(allFeedProvider.future);
      },
      child: feed.when(
        data: (posts) => posts.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('No posts yet — be the first to share. ✨'),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: posts.length,
                itemBuilder: (_, i) => PostCard(
                  key: ValueKey(posts[i].id),
                  post: posts[i],
                  type: type,
                ),
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class PostCard extends ConsumerStatefulWidget {
  final Post post;
  final String? type;
  const PostCard({super.key, required this.post, this.type});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late Map<String, int> _counts = {...widget.post.reactionCounts};
  late Set<String> _mine = {...widget.post.myReactions};
  final _pending = <String>{};

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pending.isEmpty) {
      _counts = {...widget.post.reactionCounts};
      _mine = {...widget.post.myReactions};
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final name = post.author?.fullName ?? 'Evangelist';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
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
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          [
                            post.author?.church,
                            post.city ?? post.author?.city,
                          ].where((e) => e != null && e.isNotEmpty).join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TypeBadge(type: post.type),
                ],
              ),
              const SizedBox(height: 12),
              Text(post.body),
              if (post.photoUrl != null) ...[
                const SizedBox(height: 12),
                PostPhoto(url: post.photoUrl!),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ReactionChip(
                    emoji: '🔥',
                    label: 'Encouraged',
                    count: _counts['encouraged'] ?? 0,
                    active: _mine.contains('encouraged'),
                    onTap: () => _react('encouraged'),
                  ),
                  const SizedBox(width: 8),
                  ReactionChip(
                    emoji: '🙏',
                    label: 'Praying',
                    count: _counts['praying'] ?? 0,
                    active: _mine.contains('praying'),
                    onTap: () => _react('praying'),
                  ),
                  const Spacer(),
                  CommentIndicator(count: post.commentCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _react(String reaction) async {
    if (_pending.contains(reaction)) return;
    // Guests must create an account before reacting.
    if (!await requireAccount(context, ref)) return;
    if (!mounted) return;
    final wasOn = _mine.contains(reaction);
    final oldCount = _counts[reaction] ?? 0;
    setState(() {
      _pending.add(reaction);
      if (wasOn) {
        _mine.remove(reaction);
        _counts[reaction] = (oldCount - 1).clamp(0, 1 << 30);
      } else {
        _mine.add(reaction);
        _counts[reaction] = oldCount + 1;
      }
    });

    try {
      await ref
          .read(feedRepoProvider)
          .toggleReaction(widget.post.id, reaction, !wasOn);
      // No feed invalidation here: this card already holds the authoritative
      // optimistic state. Refetching all 50 posts + their reactions on every
      // tap is wasteful and can make rapid taps feel laggy. The next natural
      // refresh (pull-to-refresh / tab reload) reconciles counts.
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (wasOn) {
          _mine.add(reaction);
        } else {
          _mine.remove(reaction);
        }
        _counts[reaction] = oldCount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save reaction: $error')),
      );
    } finally {
      if (mounted) setState(() => _pending.remove(reaction));
    }
  }
}

class ReactionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const ReactionChip({
    super.key,
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
        child: Text(
          '$emoji $label${count > 0 ? ' $count' : ''}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
