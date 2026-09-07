import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The lead pastor's contact details, as collected on the register and claim
/// forms. Kept separate from the submitter: a member can register their
/// church, but the team verifies it with the person who leads it.
class PastorDetails {
  final name = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final bestTime = TextEditingController();

  /// When the submitter IS the lead pastor, their own details are used and
  /// the pastor fields are hidden.
  bool iAmPastor = false;

  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    bestTime.dispose();
  }

  /// A message to show the user, or null when the details are complete. The
  /// team needs a name plus at least one way to reach the pastor.
  String? validate({
    required String submitterName,
    required String submitterPhone,
    required String submitterEmail,
  }) {
    if (iAmPastor) {
      if (submitterName.trim().isEmpty) return 'Your name is required';
      if (submitterPhone.trim().isEmpty && submitterEmail.trim().isEmpty) {
        return 'Add your phone or email so our team can reach you';
      }
      return null;
    }
    if (name.text.trim().isEmpty) return 'The lead pastor\'s name is required';
    if (phone.text.trim().isEmpty && email.text.trim().isEmpty) {
      return 'Add the lead pastor\'s phone or email so our team can reach them';
    }
    return null;
  }

  /// The values to store, after applying [iAmPastor].
  ({String? name, String? phone, String? email, String? bestTime}) resolve({
    required String submitterName,
    required String submitterPhone,
    required String submitterEmail,
  }) {
    String? clean(String s) => s.trim().isEmpty ? null : s.trim();
    return (
      name: clean(iAmPastor ? submitterName : name.text),
      phone: clean(iAmPastor ? submitterPhone : phone.text),
      email: clean(iAmPastor ? submitterEmail : email.text),
      bestTime: clean(bestTime.text),
    );
  }
}

/// The "I am the lead pastor" switch plus the pastor fields it reveals.
class PastorFields extends StatelessWidget {
  const PastorFields({
    super.key,
    required this.details,
    required this.onChanged,
  });

  final PastorDetails details;

  /// Called when the switch flips so the parent form can rebuild.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: AppColors.accent,
          title: const Text('I am the lead pastor'),
          value: details.iAmPastor,
          onChanged: (v) {
            details.iAmPastor = v;
            onChanged();
          },
        ),
        if (!details.iAmPastor) ...[
          _field(details.name, 'Lead pastor\'s name *'),
          _field(
            details.phone,
            'Pastor\'s phone',
            keyboard: TextInputType.phone,
          ),
          _field(
            details.email,
            'Pastor\'s email',
            keyboard: TextInputType.emailAddress,
          ),
        ],
        _field(
          details.bestTime,
          'Best time to call or visit (e.g. weekday mornings)',
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

/// Bold section heading used by the church forms.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    );
  }
}
