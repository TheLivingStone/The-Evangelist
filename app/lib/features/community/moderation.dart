import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/glass.dart';
import '../../core/providers.dart';

/// Reasons offered when reporting. Kept short and concrete so the report is
/// actionable without a free-text follow-up.
const _reasons = <String>[
  'Spam or misleading',
  'Harassment or bullying',
  'Hate speech',
  'Violence or threats',
  'Nudity or sexual content',
  'Other',
];

/// Shows the overflow menu for a post or comment: Report, Block, and (for the
/// user's own content) nothing else — authors moderate their own posts by
/// deleting them.
Future<void> showModerationSheet(
  BuildContext context,
  WidgetRef ref, {
  String? postId,
  String? commentId,
  required String authorId,
  required String authorName,
}) async {
  final myId = ref.read(currentUserIdProvider);
  final isMine = myId != null && myId == authorId;
  if (isMine) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('This is your own post.')));
    return;
  }

  await showGlassSheet<void>(
    context,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report'),
            subtitle: const Text('Tell us this content is objectionable'),
            onTap: () {
              Navigator.pop(sheetContext);
              _showReportDialog(
                context,
                ref,
                postId: postId,
                commentId: commentId,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text('Block $authorName'),
            subtitle: const Text('You will no longer see their content'),
            onTap: () {
              Navigator.pop(sheetContext);
              _confirmBlock(context, ref, authorId, authorName);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  String? postId,
  String? commentId,
}) async {
  var selected = _reasons.first;
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Report content'),
        content: RadioGroup<String>(
          groupValue: selected,
          onChanged: (v) => setState(() => selected = v!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in _reasons)
                RadioListTile<String>(
                  value: r,
                  title: Text(r),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, selected),
            child: const Text('Submit report'),
          ),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;

  try {
    await ref
        .read(moderationRepoProvider)
        .report(postId: postId, commentId: commentId, reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Report submitted. Our team will review it within 24 hours.',
        ),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not submit report: $error')));
  }
}

Future<void> _confirmBlock(
  BuildContext context,
  WidgetRef ref,
  String authorId,
  String authorName,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Block $authorName?'),
      content: const Text(
        'Their posts and comments will be hidden from you. '
        'You can undo this in Profile → Blocked accounts.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  try {
    await ref.read(moderationRepoProvider).block(authorId);
    ref.invalidate(allFeedProvider);
    ref.invalidate(blockedProfilesProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$authorName blocked.')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not block: $error')));
  }
}
