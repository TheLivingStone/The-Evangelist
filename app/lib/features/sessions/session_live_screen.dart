import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'session_summary_screen.dart';

class SessionLiveScreen extends ConsumerStatefulWidget {
  final OutreachSession session;
  const SessionLiveScreen({super.key, required this.session});
  @override
  ConsumerState<SessionLiveScreen> createState() => _SessionLiveScreenState();
}

class _SessionLiveScreenState extends ConsumerState<SessionLiveScreen> {
  late int _conversations = widget.session.conversationsCount;
  late int _prayers = widget.session.prayersCount;
  late int _peopleAdded = widget.session.peopleAddedCount;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        // startedAt is a UTC timestamp from Postgres; compare in UTC so the
        // elapsed time isn't skewed by the device's timezone offset.
        _elapsed = DateTime.now().toUtc().difference(
          widget.session.startedAt.toUtc(),
        );
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _fmt {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _end() async {
    setState(() => _ending = true);
    try {
      await ref
          .read(sessionsRepoProvider)
          .end(
            widget.session.id,
            conversations: _conversations,
            prayers: _prayers,
            peopleAdded: _peopleAdded,
          );
      ref.invalidate(liveSessionProvider);
      ref.invalidate(myProfileProvider);
      ref.invalidate(monthCountsProvider);
      ref.invalidate(recentActivityProvider);
      ref.invalidate(weekDaysActiveProvider);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SessionSummaryScreen(
              duration: _elapsed,
              conversations: _conversations,
              prayers: _prayers,
              peopleAdded: _peopleAdded,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not end session: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dBg,
      appBar: AppBar(
        backgroundColor: AppColors.dBg,
        foregroundColor: Colors.white,
        title: const Text('Outreach Live'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'You are evangelising',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _fmt,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 32),
            _counter(
              '💬 Conversations',
              _conversations,
              () => setState(() => _conversations++),
            ),
            _counter('🙏 Prayers', _prayers, () => setState(() => _prayers++)),
            _counter(
              '👥 People Added',
              _peopleAdded,
              () => setState(() => _peopleAdded++),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5484D),
                ),
                onPressed: _ending ? null : _end,
                child: _ending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('End Session'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter(String label, int value, VoidCallback onTap) {
    return Card(
      color: AppColors.dSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filled(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(backgroundColor: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
