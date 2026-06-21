import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Form for a pastor to claim an EXISTING church listing. Records who they are
/// and flips the church to "pending" so an owner can verify them.
class ClaimChurchScreen extends ConsumerStatefulWidget {
  final Church church;
  const ClaimChurchScreen({super.key, required this.church});
  @override
  ConsumerState<ClaimChurchScreen> createState() => _ClaimChurchScreenState();
}

class _ClaimChurchScreenState extends ConsumerState<ClaimChurchScreen> {
  final _name = TextEditingController();
  final _role = TextEditingController(text: 'Lead Pastor');
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    if (profile != null) _name.text = profile.fullName;
  }

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _phone.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _role.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your name and role are required')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(churchesRepoProvider).claim(
            churchId: widget.church.id,
            claimantName: _name.text.trim(),
            claimantRole: _role.text.trim(),
            claimantPhone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            claimantEmail: _email.text.trim().isEmpty ? null : _email.text.trim(),
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit claim: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim this church')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.church.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us who you are. Our team verifies every church leader before '
            'a listing is marked trusted — we may contact you to confirm.',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 18),
          _field(_name, 'Your name *'),
          _field(_role, 'Your role (e.g. Lead Pastor) *'),
          _field(_phone, 'Phone', keyboard: TextInputType.phone),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_message, 'Anything we should know? (optional)', lines: 3),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit claim',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: lines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
