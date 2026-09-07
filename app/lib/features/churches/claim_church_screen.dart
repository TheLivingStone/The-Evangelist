import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_account.dart';
import '../../core/glass.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import 'pastor_fields.dart';

/// Form for a pastor (or a member on their behalf) to claim an EXISTING
/// church listing. Records who they are and the lead pastor's contact details,
/// then flips the church to "pending" so the team can verify it in person.
class ClaimChurchScreen extends ConsumerStatefulWidget {
  final Church church;
  const ClaimChurchScreen({super.key, required this.church});
  @override
  ConsumerState<ClaimChurchScreen> createState() => _ClaimChurchScreenState();
}

class _ClaimChurchScreenState extends ConsumerState<ClaimChurchScreen> {
  final _name = TextEditingController();
  final _role = TextEditingController(text: 'Member');
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  // Most claims come from the pastor themselves, so start with the switch on.
  final _pastor = PastorDetails()..iAmPastor = true;
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
    _pastor.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      _snack('Your name is required');
      return;
    }
    final pastorError = _pastor.validate(
      submitterName: _name.text,
      submitterPhone: _phone.text,
      submitterEmail: _email.text,
    );
    if (pastorError != null) {
      _snack(pastorError);
      return;
    }
    if (!await requireAccount(context, ref)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final pastor = _pastor.resolve(
        submitterName: _name.text,
        submitterPhone: _phone.text,
        submitterEmail: _email.text,
      );
      String? clean(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref
          .read(churchesRepoProvider)
          .claim(
            churchId: widget.church.id,
            claimantName: _name.text.trim(),
            claimantRole: _pastor.iAmPastor
                ? 'Lead Pastor'
                : (clean(_role) ?? 'Member'),
            claimantPhone: clean(_phone),
            claimantEmail: clean(_email),
            message: clean(_message),
            pastorName: pastor.name,
            pastorPhone: pastor.phone,
            pastorEmail: pastor.email,
            bestTimeToMeet: pastor.bestTime,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) _snack('Could not submit claim: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.65);
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Claim this church')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.church.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Tell us who you are. Our team contacts the lead pastor, books a '
            'short visit, and only then marks the church verified.',
            style: TextStyle(fontSize: 13, color: muted),
          ),
          const SizedBox(height: 18),
          const SectionLabel('Lead pastor'),
          PastorFields(details: _pastor, onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          SectionLabel(_pastor.iAmPastor ? 'Your details' : 'About you'),
          _field(_name, 'Your name *'),
          if (!_pastor.iAmPastor)
            _field(_role, 'Your role (e.g. Elder, Member)'),
          _field(
            _phone,
            _pastor.iAmPastor ? 'Phone *' : 'Phone',
            keyboard: TextInputType.phone,
          ),
          _field(
            _email,
            _pastor.iAmPastor ? 'Email *' : 'Email',
            keyboard: TextInputType.emailAddress,
          ),
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
