import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class EncouragementScreen extends ConsumerStatefulWidget {
  const EncouragementScreen({super.key});
  @override
  ConsumerState<EncouragementScreen> createState() =>
      _EncouragementScreenState();
}

class _EncouragementScreenState extends ConsumerState<EncouragementScreen> {
  Verse? _verse;
  bool _loading = true;
  final _tasks = <MapEntry<String, bool>>[
    const MapEntry('Pray for boldness', false),
    const MapEntry('Share the Gospel with someone', false),
    const MapEntry('Encourage another evangelist', false),
  ];

  @override
  void initState() {
    super.initState();
    _newVerse();
  }

  Future<void> _newVerse() async {
    setState(() => _loading = true);
    Verse? v;
    try {
      v = await ref.read(encouragementRepoProvider).randomVerse();
    } catch (_) {
      v = null;
    }
    if (!mounted) return;
    setState(() {
      _verse = v;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Encouragement')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.accent.withValues(alpha: 0.18),
                        AppColors.purple.withValues(alpha: 0.08),
                      ]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            _verse == null
                                ? 'Go into all the world and proclaim the gospel to the whole creation.'
                                : '"${_verse!.text}"',
                            style: const TextStyle(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text('— ${_verse?.reference ?? 'Mark 16:15'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _newVerse,
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Verse'),
                  ),
                ),
                const SizedBox(height: 8),
                const Text("Today's mission",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                ..._tasks.asMap().entries.map((e) => CheckboxListTile(
                      title: Text(e.value.key),
                      value: e.value.value,
                      activeColor: AppColors.green,
                      onChanged: (v) => setState(() =>
                          _tasks[e.key] = MapEntry(e.value.key, v ?? false)),
                    )),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("I'm on it!"),
                ),
              ],
            ),
    );
  }
}
