import 'package:flutter/material.dart';
import '../community/composer_screen.dart';

class SessionSummaryScreen extends StatelessWidget {
  final Duration duration;
  final int conversations;
  final int prayers;
  final int peopleAdded;
  const SessionSummaryScreen({
    super.key,
    required this.duration,
    required this.conversations,
    required this.prayers,
    required this.peopleAdded,
  });

  String get _dur {
    final m = duration.inMinutes;
    return m < 60 ? '$m min' : '${duration.inHours}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Session Complete 🎉'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Well done, faithful evangelist!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _row(context, 'Duration', _dur),
                    _row(context, 'Conversations', '$conversations'),
                    _row(context, 'Prayers', '$prayers'),
                    _row(context, 'People added', '$peopleAdded'),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Share Testimony'),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ComposerScreen(
                        initialType: 'outreach',
                        prefill:
                            'Just finished an outreach session — $conversations conversations, $prayers prayers in $_dur. God is good! 🔥',
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6))),
            Text(v,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
