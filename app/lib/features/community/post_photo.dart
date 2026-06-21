import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Renders a post's photo from its public URL with a fixed, rounded frame.
/// Used in both the feed card and the post detail screen.
class PostPhoto extends StatelessWidget {
  final String url;
  const PostPhoto({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              color: Colors.grey.withValues(alpha: 0.12),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            );
          },
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey.withValues(alpha: 0.12),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 32),
          ),
        ),
      ),
    );
  }
}

/// Colored pill showing the post type (Testimony / Outreach / …).
class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge({super.key, required this.type});

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
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Small "💬 N" affordance shown on a feed card to signal comment count.
class CommentIndicator extends StatelessWidget {
  final int count;
  const CommentIndicator({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mode_comment_outlined, size: 16, color: muted),
        const SizedBox(width: 4),
        Text(
          count == 0 ? 'Reply' : '$count',
          style: TextStyle(fontSize: 13, color: muted),
        ),
      ],
    );
  }
}
