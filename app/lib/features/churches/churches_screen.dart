import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'register_church_screen.dart';
import 'claim_church_screen.dart';
import 'manage_members_screen.dart';

/// Public church directory. Lists churches near the user's location and lets
/// them register a new one or claim an existing listing. Verified churches are
/// badged as trusted; everything else is clearly marked "Pending review".
class ChurchesScreen extends ConsumerStatefulWidget {
  const ChurchesScreen({super.key});
  @override
  ConsumerState<ChurchesScreen> createState() => _ChurchesScreenState();
}

class _ChurchesScreenState extends ConsumerState<ChurchesScreen> {
  Future<List<Church>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Church>> _load() async {
    final repo = ref.read(churchesRepoProvider);
    // Best-effort location; fall back to a default metro if unavailable so the
    // directory still renders.
    double lat = 33.749, lng = -84.388; // Atlanta default
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 15),
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      }
    } catch (_) {
      // keep defaults
    }
    return repo.nearby(lat, lng);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _openRegister() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterChurchScreen()),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Churches')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: _openRegister,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Register a church',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<Church>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snap.hasError) {
            return Center(child: Text('Could not load churches: ${snap.error}'));
          }
          final churches = snap.data ?? [];
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: churches.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No churches nearby yet.\nBe the first to register one. 🙏',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: churches.length + 2,
                    itemBuilder: (_, i) {
                      if (i == 0) return const _DirectoryNote();
                      if (i == 1) return const _MembershipBanner();
                      return _ChurchCard(church: churches[i - 2]);
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _DirectoryNote extends StatelessWidget {
  const _DirectoryNote();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Text(
        'Verified churches have been personally confirmed by our team. '
        'Churches marked "Pending review" are not yet verified.',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ChurchCard extends ConsumerWidget {
  final Church church;
  const _ChurchCard({required this.church});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtitle = [
      church.city,
      church.serviceTimes,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    church.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _VerifyBadge(verified: church.isVerified),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
            if (church.address != null && church.address!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                church.address!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _CardActions(church: church),
          ],
        ),
      ),
    );
  }
}

/// Action row on each church card: the member "I attend here" button (reflecting
/// current membership state), the pastor "claim / lead" button, and — for the
/// manager of this church — a shortcut to confirm members.
class _CardActions extends ConsumerWidget {
  final Church church;
  const _CardActions({required this.church});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider).value;
    final attendsThis = membership != null && membership.churchId == church.id;

    Future<void> attend() async {
      try {
        await ref.read(churchesRepoProvider).joinChurch(church.id);
        ref.invalidate(myMembershipProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Marked as your church — the church will confirm you. 🙏',
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not join: $error')),
          );
        }
      }
    }

    Future<void> leave() async {
      try {
        await ref.read(churchesRepoProvider).leaveChurch();
        ref.invalidate(myMembershipProvider);
      } catch (_) {}
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (attendsThis)
          _AttendChip(
            confirmed: membership.isConfirmed,
            onLeave: leave,
          )
        else
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: attend,
            icon: const Icon(Icons.favorite_outline, size: 18),
            label: const Text('I attend here'),
          ),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () async {
            final done = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => ClaimChurchScreen(church: church),
              ),
            );
            if (done == true && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Claim submitted — our team will reach out to verify.',
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.verified_user_outlined, size: 18),
          label: const Text('I lead this church'),
        ),
        TextButton.icon(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManageMembersScreen(church: church),
            ),
          ),
          icon: const Icon(Icons.group_outlined, size: 18),
          label: const Text('Members'),
        ),
      ],
    );
  }
}

class _AttendChip extends StatelessWidget {
  final bool confirmed;
  final VoidCallback onLeave;
  const _AttendChip({required this.confirmed, required this.onLeave});
  @override
  Widget build(BuildContext context) {
    final color = confirmed ? AppColors.green : AppColors.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                confirmed ? Icons.check_circle : Icons.hourglass_top,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                confirmed ? 'Your church' : 'Pending confirmation',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onLeave,
          child: const Text('Leave', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}

/// Top-of-list banner summarising the user's home-church status.
class _MembershipBanner extends ConsumerWidget {
  const _MembershipBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(myMembershipProvider).value;
    if (m == null) return const SizedBox.shrink();
    final color = m.isConfirmed ? AppColors.green : AppColors.accent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.church_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.isConfirmed
                        ? 'You attend ${m.churchName}'
                        : 'Waiting on ${m.churchName} to confirm you',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    m.isConfirmed
                        ? 'Your evangelism counts toward your church. 🔥'
                        : 'Once confirmed, your activity counts toward your church.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.65),
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
}

class _VerifyBadge extends StatelessWidget {
  final bool verified;
  const _VerifyBadge({required this.verified});
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = verified
        ? ('Verified', AppColors.green, Icons.verified)
        : ('Pending review', AppColors.dMuted, Icons.hourglass_empty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
