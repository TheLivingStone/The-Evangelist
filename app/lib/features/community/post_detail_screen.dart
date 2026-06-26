import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth_account.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'community_screen.dart' show ReactionChip;
import 'post_photo.dart';

/// Full view of a single post: header, body, optional photo, reactions, and
/// the comment thread with an inline composer at the bottom.
class PostDetailScreen extends ConsumerStatefulWidget {
  final Post post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  // Local reaction state mirrors the feed card so taps feel instant here too.
  late final Map<String, int> _counts = {...widget.post.reactionCounts};
  late final Set<String> _mine = {...widget.post.myReactions};
  final _pending = <String>{};

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _react(String reaction) async {
    if (_pending.contains(reaction)) return;
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    if (!await requireAccount(context, ref)) return;
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(commentsRepoProvider).add(widget.post.id, text);
      _input.clear();
      ref.invalidate(commentsProvider(widget.post.id));
      // Bump the comment count in the feed so the card reflects the new reply.
      ref.invalidate(allFeedProvider);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not post comment: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final comments = ref.watch(commentsProvider(post.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: [
                _PostHeader(post: post),
                const SizedBox(height: 12),
                Text(post.body, style: const TextStyle(fontSize: 16)),
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
                  ],
                ),
                const Divider(height: 32),
                comments.when(
                  data: (list) => list.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No replies yet — be the first. 🙏'),
                          ),
                        )
                      : Column(
                          children: [
                            for (final c in list) _CommentTile(comment: c),
                          ],
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Could not load replies: $e')),
                  ),
                ),
              ],
            ),
          ),
          _CommentComposer(
            controller: _input,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final Post post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final name = post.author?.fullName ?? 'Evangelist';
    return Row(
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
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final name = comment.author?.fullName ?? 'Evangelist';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            child: Text(name.characters.first, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(comment.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 8,
          top: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Write an encouragement…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: AppColors.accent),
                    onPressed: onSend,
                  ),
          ],
        ),
      ),
    );
  }
}
