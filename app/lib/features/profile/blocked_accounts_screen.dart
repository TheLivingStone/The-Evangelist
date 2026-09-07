import 'package:flutter/material.dart';
import '../../core/glass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Lets a user review and undo their blocks (App Store Guideline 1.2 requires
/// blocking to be manageable, not one-way).
class BlockedAccountsScreen extends ConsumerWidget {
  const BlockedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedProfilesProvider);
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Blocked accounts')),
      body: blocked.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load blocked accounts: $error'),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'You have not blocked anyone.\n\n'
                  'Blocking someone hides their posts and comments from you.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final profile = list[i];
              final name = profile.fullName;
              return ListTile(
                leading: CircleAvatar(child: Text(name.characters.first)),
                title: Text(name),
                trailing: TextButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(moderationRepoProvider)
                          .unblock(profile.id);
                      ref.invalidate(blockedProfilesProvider);
                      ref.invalidate(allFeedProvider);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$name unblocked.')),
                      );
                    } catch (error) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not unblock: $error')),
                      );
                    }
                  },
                  child: const Text('Unblock'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
