import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/models.dart';

class AddPersonScreen extends ConsumerStatefulWidget {
  const AddPersonScreen({super.key});
  @override
  ConsumerState<AddPersonScreen> createState() => _AddPersonScreenState();
}

class _AddPersonScreenState extends ConsumerState<AddPersonScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _met = TextEditingController();
  final _notes = TextEditingController();
  String _status = 'new_contact';
  DateTime? _nextFollowup = DateTime.now().add(const Duration(days: 1));
  bool _busy = false;

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('First name is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(contactsRepoProvider).add({
        'first_name': _first.text.trim(),
        if (_last.text.trim().isNotEmpty) 'last_name': _last.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_met.text.trim().isNotEmpty) 'met_location': _met.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'status': _status,
        if (_nextFollowup != null)
          'next_followup_at':
              _nextFollowup!.toIso8601String().substring(0, 10),
      });
      ref.invalidate(dueFollowupsProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Person')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_first, 'First name *'),
          _field(_last, 'Last name'),
          _field(_phone, 'Phone', keyboard: TextInputType.phone),
          _field(_email, 'Email', keyboard: TextInputType.emailAddress),
          _field(_met, 'Where you met'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Spiritual status'),
            items: spiritualStatuses
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(prettyStatus(s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? 'new_contact'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next follow-up'),
            subtitle: Text(_nextFollowup == null
                ? 'None'
                : _nextFollowup!.toIso8601String().substring(0, 10)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _nextFollowup ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _nextFollowup = picked);
            },
          ),
          _field(_notes, 'Notes (what happened)', maxLines: 3),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Save Person'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
