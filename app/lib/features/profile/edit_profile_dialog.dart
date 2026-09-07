import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/supabase.dart';
import '../../models/models.dart';

/// Edit the display name and city. Until this existed there was no way to
/// change a name at all — which mattered because Apple only sends the name on
/// the very first sign-in, leaving many profiles on the 'Evangelist' default.
Future<void> showEditProfileDialog(BuildContext context, Profile profile) {
  return showDialog<void>(
    context: context,
    builder: (_) => _EditProfileDialog(profile: profile),
  );
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.profile});
  final Profile profile;
  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final _name = TextEditingController(
    text: widget.profile.hasRealName ? widget.profile.fullName : '',
  );
  late final _city = TextEditingController(text: widget.profile.city ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepoProvider).update({
        'full_name': name,
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
      });
      try {
        await supabase.auth.updateUser(
          UserAttributes(data: {'full_name': name}),
        );
      } catch (_) {
        /* best-effort */
      }
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'City (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFE5484D)),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
