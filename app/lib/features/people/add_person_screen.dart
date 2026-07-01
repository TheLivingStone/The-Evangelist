import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
  bool? _shareOverride;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _email.dispose();
    _met.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Best-effort GPS fix at the moment of saving, so a contact silently
  /// remembers where it was created. Never blocks or errors the save —
  /// permission denied / services off / timeout all just mean no location.
  Future<(double, double)?> _captureLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('First name is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      final confirmedChurch =
          ref.read(myMembershipProvider).value?.isConfirmed == true;
      final shareWithChurch =
          _shareOverride ??
          ref.read(myProfileProvider).value?.shareContactsWithChurch ??
          false;
      final location = await _captureLocation();
      await ref.read(contactsRepoProvider).add({
        'first_name': _first.text.trim(),
        if (_last.text.trim().isNotEmpty) 'last_name': _last.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_met.text.trim().isNotEmpty) 'met_location': _met.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'status': _status,
        if (_nextFollowup != null)
          'next_followup_at': _nextFollowup!.toIso8601String().substring(0, 10),
        if (confirmedChurch && shareWithChurch) 'visible_to_church': true,
        if (location != null) 'met_lat': location.$1,
        if (location != null) 'met_lng': location.$2,
      });
      ref.invalidate(contactsListProvider);
      ref.invalidate(dueFollowupsProvider);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save person: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(myMembershipProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final canShareWithChurch = membership?.isConfirmed == true;
    final shareWithChurch =
        _shareOverride ?? profile?.shareContactsWithChurch ?? false;
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
                .map(
                  (s) =>
                      DropdownMenuItem(value: s, child: Text(prettyStatus(s))),
                )
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? 'new_contact'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next follow-up'),
            subtitle: Text(
              _nextFollowup == null
                  ? 'None'
                  : _nextFollowup!.toIso8601String().substring(0, 10),
            ),
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
          if (canShareWithChurch) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share with my church'),
              subtitle: Text(
                '${membership!.churchName} will be able to see this '
                "person's info to follow up.",
              ),
              value: shareWithChurch,
              onChanged: (v) => setState(() => _shareOverride = v),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Save Person'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
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
