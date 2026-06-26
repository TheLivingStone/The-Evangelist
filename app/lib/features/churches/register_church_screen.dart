import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/auth_account.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

/// Form to register a NEW church. Uses the user's current GPS as the church
/// location (they're assumed to be at/near it). The church is created
/// unverified + pending; an owner vets it before it shows as trusted.
class RegisterChurchScreen extends ConsumerStatefulWidget {
  const RegisterChurchScreen({super.key});
  @override
  ConsumerState<RegisterChurchScreen> createState() =>
      _RegisterChurchScreenState();
}

class _RegisterChurchScreenState extends ConsumerState<RegisterChurchScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _serviceTimes = TextEditingController();
  final _website = TextEditingController();
  final _claimName = TextEditingController();
  final _claimRole = TextEditingController(text: 'Lead Pastor');
  final _claimPhone = TextEditingController();
  final _claimEmail = TextEditingController();

  bool _busy = false;
  bool _locating = false;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    if (profile != null) {
      _claimName.text = profile.fullName;
      if (profile.city != null) _city.text = profile.city!;
    }
    // Try to capture location up front so the user sees it's set.
    _captureLocation();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _serviceTimes.dispose();
    _website.dispose();
    _claimName.dispose();
    _claimRole.dispose();
    _claimPhone.dispose();
    _claimEmail.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location services are turned off');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $error')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Church name is required')),
      );
      return;
    }
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap "Use my current location" so the church appears on the map'),
        ),
      );
      return;
    }
    if (!await requireAccount(context, ref)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(churchesRepoProvider).register(
            name: _name.text.trim(),
            lat: _lat!,
            lng: _lng!,
            address: _text(_address),
            city: _text(_city),
            serviceTimes: _text(_serviceTimes),
            website: _text(_website),
            claimantName: _text(_claimName),
            claimantRole: _text(_claimRole),
            claimantPhone: _text(_claimPhone),
            claimantEmail: _text(_claimEmail),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Church submitted! Our team will reach out to verify before it\'s marked trusted.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not register church: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register a church')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionLabel('About the church'),
          _field(_name, 'Church name *'),
          _field(_address, 'Address'),
          _field(_city, 'City'),
          _field(_serviceTimes, 'Service times (e.g. Sun 9am & 11am)'),
          _field(_website, 'Website', keyboard: TextInputType.url),
          const SizedBox(height: 8),
          _LocationTile(
            lat: _lat,
            lng: _lng,
            locating: _locating,
            onTap: _captureLocation,
          ),
          const SizedBox(height: 20),
          _SectionLabel('Your details (for verification)'),
          Text(
            'We verify every church before sending people there, so we may '
            'contact you to confirm you lead this church.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _field(_claimName, 'Your name'),
          _field(_claimRole, 'Your role (e.g. Lead Pastor)'),
          _field(_claimPhone, 'Phone', keyboard: TextInputType.phone),
          _field(_claimEmail, 'Email', keyboard: TextInputType.emailAddress),
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
                    'Submit for verification',
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
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

class _LocationTile extends StatelessWidget {
  final double? lat;
  final double? lng;
  final bool locating;
  final VoidCallback onTap;
  const _LocationTile({
    required this.lat,
    required this.lng,
    required this.locating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final set = lat != null && lng != null;
    return InkWell(
      onTap: locating ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: set ? AppColors.green : AppColors.accent,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              set ? Icons.location_on : Icons.my_location,
              color: set ? AppColors.green : AppColors.accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                locating
                    ? 'Getting your location…'
                    : set
                    ? 'Location set ✓  (${lat!.toStringAsFixed(4)}, ${lng!.toStringAsFixed(4)})'
                    : 'Use my current location',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: set ? AppColors.green : AppColors.accent,
                ),
              ),
            ),
            if (locating)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
