import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// For a church MANAGER (the claimant): confirm or remove the people who marked
/// this as their home church. Non-managers see an empty list (the RPC scopes to
/// churches the caller manages).
class ManageMembersScreen extends ConsumerWidget {
  final Church church;
  const ManageMembersScreen({super.key, required this.church});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(churchMembersProvider(church.id));
    return Scaffold(
      appBar: AppBar(title: Text('${church.name} · Members')),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Could not load members: $e')),
        data: (members) {
          if (members.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No one has marked this as their church yet.\n\n'
                    'Only the church manager can confirm members. If you lead '
                    'this church, claim it first.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          }
          final pending = members.where((m) => m.isPending).toList();
          final confirmed = members.where((m) => !m.isPending).toList();
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(churchMembersProvider(church.id)),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (pending.isNotEmpty) ...[
                  const _SectionLabel('Pending confirmation'),
                  ...pending.map((m) => _MemberTile(church: church, member: m)),
                  const SizedBox(height: 12),
                ],
                _SectionLabel('Confirmed members (${confirmed.length})'),
                if (confirmed.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No confirmed members yet.'),
                  )
                else
                  ...confirmed
                      .map((m) => _MemberTile(church: church, member: m)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
}

class _MemberTile extends ConsumerStatefulWidget {
  final Church church;
  final ChurchMemberRequest member;
  const _MemberTile({required this.church, required this.member});
  @override
  ConsumerState<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends ConsumerState<_MemberTile> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String failMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(churchMembersProvider(widget.church.id));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failMsg: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final repo = ref.read(churchesRepoProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              backgroundImage:
                  m.avatarUrl != null ? NetworkImage(m.avatarUrl!) : null,
              child: m.avatarUrl == null
                  ? Text(
                      (m.fullName ?? '?').characters.first.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.accent2,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.fullName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${m.city ?? '—'} · ${m.totalSalvations} saved · '
                    '${m.totalConversations} talks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (m.isPending)
                    IconButton(
                      tooltip: 'Confirm',
                      icon: const Icon(Icons.check_circle, color: AppColors.green),
                      onPressed: () => _run(
                        () => repo.confirmMember(m.membershipId),
                        'Could not confirm',
                      ),
                    ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppColors.pink),
                    onPressed: () => _run(
                      () => repo.removeMember(m.membershipId),
                      'Could not remove',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
