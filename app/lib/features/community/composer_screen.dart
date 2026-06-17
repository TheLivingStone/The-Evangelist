import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class ComposerScreen extends ConsumerStatefulWidget {
  final String initialType;
  final String? prefill;
  const ComposerScreen({super.key, this.initialType = 'testimony', this.prefill});

  @override
  ConsumerState<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends ConsumerState<ComposerScreen> {
  late String _type = widget.initialType;
  late final _body = TextEditingController(text: widget.prefill ?? '');
  bool _busy = false;

  static const _types = ['testimony', 'outreach', 'prayer', 'salvation', 'update'];

  Future<void> _post() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final profile = ref.read(myProfileProvider).value;
      await ref.read(feedRepoProvider).create(_type, _body.text.trim(),
          city: profile?.city);
      ref.invalidate(feedProvider(null));
      ref.invalidate(feedProvider(_type));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share what God did'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _post,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post',
                    style: TextStyle(
                        color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: _types
                  .map((t) => ChoiceChip(
                        label: Text(t[0].toUpperCase() + t.substring(1)),
                        selected: _type == t,
                        selectedColor: AppColors.accent.withValues(alpha: 0.25),
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: _body,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                    hintText: 'Share what God did today…'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
