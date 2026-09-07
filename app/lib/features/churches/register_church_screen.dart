import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/auth_account.dart';
import '../../core/geocode.dart';
import '../../core/glass.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'pastor_fields.dart';

/// Form to register a NEW church.
///
/// Type the address and tap search: the geocoder fills in the city and pins
/// the church on the map. "Use my current location" does the reverse and
/// fills the address from GPS. We also collect the LEAD PASTOR's contact
/// details (separate from whoever is filling this in) so the team can call or
/// email them, book a short visit, and confirm the church really is taking
/// part before it is marked verified.
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
  final _pastor = PastorDetails();
  final _claimName = TextEditingController();
  final _claimRole = TextEditingController(text: 'Member');
  final _claimPhone = TextEditingController();
  final _claimEmail = TextEditingController();
  final _geocoder = Geocoder();

  bool _busy = false;
  bool _locating = false;
  bool _searching = false;
  double? _lat;
  double? _lng;

  /// Human-readable place once pinned, e.g. "12 Main St, Atlanta, Georgia".
  String? _placeLabel;

  /// Where the pin came from. An address the user typed always beats a GPS
  /// fix: people register their church from home, so GPS is often the wrong
  /// place entirely.
  _PinSource _pinSource = _PinSource.none;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(myProfileProvider).value;
    if (profile != null) {
      _claimName.text = profile.fullName;
      if (profile.city != null) _city.text = profile.city!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _serviceTimes.dispose();
    _website.dispose();
    _pastor.dispose();
    _claimName.dispose();
    _claimRole.dispose();
    _claimPhone.dispose();
    _claimEmail.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Fill the form from a geocoder match. With [overwrite] false, only empty
  /// fields are filled so nothing the user typed is lost; with [movePin]
  /// false the coordinates stay where they were (used after a GPS fix, where
  /// the reverse lookup only supplies the address text).
  void _applyPlace(GeoPlace p, {bool overwrite = true, bool movePin = true}) {
    setState(() {
      if (movePin) {
        _lat = p.lat;
        _lng = p.lng;
        _pinSource = _PinSource.address;
      }
      _placeLabel = p.shortAddress;
      if (p.street != null && (overwrite || _address.text.trim().isEmpty)) {
        _address.text = p.street!;
      }
      if (p.city != null && (overwrite || _city.text.trim().isEmpty)) {
        _city.text = p.city!;
      }
    });
  }

  /// Address text → coordinates (+ city). One match applies directly; several
  /// let the user pick.
  Future<void> _findAddress() async {
    FocusScope.of(context).unfocus();
    final query = [
      _address.text.trim(),
      _city.text.trim(),
    ].where((s) => s.isNotEmpty).join(', ');
    if (query.isEmpty) {
      _snack('Type the church address first');
      return;
    }
    setState(() => _searching = true);
    try {
      var matches = await _geocoder.search(query);
      // Many churches are on the map by name; try that before giving up.
      if (matches.isEmpty && _name.text.trim().isNotEmpty) {
        matches = await _geocoder.search(
          [
            _name.text.trim(),
            _city.text.trim(),
          ].where((s) => s.isNotEmpty).join(', '),
        );
      }
      if (!mounted) return;
      if (matches.isEmpty) {
        _snack('No match found — try adding the city or ZIP code');
      } else if (matches.length == 1) {
        _applyPlace(matches.first);
      } else {
        final picked = await showModalBottomSheet<GeoPlace>(
          context: context,
          showDragHandle: true,
          builder: (_) => _PlacePicker(matches: matches),
        );
        if (picked != null && mounted) _applyPlace(picked);
      }
    } catch (error) {
      if (mounted) _snack('Could not look up that address: $error');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  /// GPS → coordinates, then reverse-geocode to fill the address and city if
  /// they are still empty.
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
        _pinSource = _PinSource.gps;
        _placeLabel = 'your current location';
      });
      final place = await _geocoder.reverse(pos.latitude, pos.longitude);
      if (place != null && mounted) {
        _applyPlace(place, overwrite: false, movePin: false);
      }
    } catch (error) {
      if (!mounted) return;
      _snack('Could not get location: $error');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      _snack('Church name is required');
      return;
    }
    // A typed address always wins over a GPS fix or no pin at all: look it up
    // now so the church lands where it actually is, not where the phone is.
    if (_pinSource != _PinSource.address &&
        _pinSource != _PinSource.manual &&
        _address.text.trim().isNotEmpty) {
      setState(() => _busy = true);
      try {
        final query = [
          _address.text.trim(),
          _city.text.trim(),
        ].where((s) => s.isNotEmpty).join(', ');
        final matches = await _geocoder.search(query, limit: 1);
        if (matches.isNotEmpty && mounted) {
          _applyPlace(matches.first, overwrite: false);
        }
      } catch (_) {
        // Offline or rate-limited: fall through and use whatever pin we have.
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      if (!mounted) return;
    }
    if (_lat == null || _lng == null) {
      _snack(
        'Look up the address (search icon) or use your current location so '
        'the church shows on the map',
      );
      return;
    }
    final pastorError = _pastor.validate(
      submitterName: _claimName.text,
      submitterPhone: _claimPhone.text,
      submitterEmail: _claimEmail.text,
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
        submitterName: _claimName.text,
        submitterPhone: _claimPhone.text,
        submitterEmail: _claimEmail.text,
      );
      await ref
          .read(churchesRepoProvider)
          .register(
            name: _name.text.trim(),
            lat: _lat!,
            lng: _lng!,
            address: _text(_address),
            city: _text(_city),
            serviceTimes: _text(_serviceTimes),
            website: _text(_website),
            claimantName: _text(_claimName),
            claimantRole: _pastor.iAmPastor
                ? 'Lead Pastor'
                : (_text(_claimRole) ?? 'Member'),
            claimantPhone: _text(_claimPhone),
            claimantEmail: _text(_claimEmail),
            pastorName: pastor.name,
            pastorPhone: pastor.phone,
            pastorEmail: pastor.email,
            bestTimeToMeet: pastor.bestTime,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Church submitted! We\'ll contact the lead pastor to confirm and '
            'arrange a visit before it\'s marked verified.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _snack('Could not register church: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.6);
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Register a church')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('About the church'),
          _field(_name, 'Church name *'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _address,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _findAddress(),
              decoration: InputDecoration(
                labelText: 'Street address',
                helperText: 'Tap search to find it and fill in the rest',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Find this address',
                        icon: const Icon(Icons.search),
                        color: AppColors.accent,
                        onPressed: _findAddress,
                      ),
              ),
            ),
          ),
          _field(_city, 'City'),
          _field(_serviceTimes, 'Service times (e.g. Sun 9am & 11am)'),
          _field(_website, 'Website', keyboard: TextInputType.url),
          const SizedBox(height: 8),
          _LocationTile(
            pinned: _lat != null && _lng != null,
            label: _placeLabel,
            locating: _locating,
            onTap: _captureLocation,
          ),
          if (_lat != null && _lng != null) ...[
            const SizedBox(height: 10),
            _PinPreview(
              point: LatLng(_lat!, _lng!),
              onMove: (p) => setState(() {
                _lat = p.latitude;
                _lng = p.longitude;
                _pinSource = _PinSource.manual;
                _placeLabel = 'pin placed by hand';
              }),
            ),
            const SizedBox(height: 6),
            Text(
              'Check the pin is on the church. Tap the map to move it.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          const SizedBox(height: 24),
          const SectionLabel('Lead pastor'),
          Text(
            'Who leads this church? Our team contacts the lead pastor to '
            'confirm the church is taking part, and books a short visit '
            'before it is marked verified.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 4),
          PastorFields(details: _pastor, onChanged: () => setState(() {})),
          const SizedBox(height: 20),
          SectionLabel(_pastor.iAmPastor ? 'Your details' : 'About you'),
          Text(
            _pastor.iAmPastor
                ? 'We\'ll reach you at the phone or email below.'
                : 'In case we have a question about this submission.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 12),
          _field(_claimName, 'Your name *'),
          if (!_pastor.iAmPastor)
            _field(_claimRole, 'Your role (e.g. Elder, Member)'),
          _field(
            _claimPhone,
            _pastor.iAmPastor ? 'Phone *' : 'Phone',
            keyboard: TextInputType.phone,
          ),
          _field(
            _claimEmail,
            _pastor.iAmPastor ? 'Email *' : 'Email',
            keyboard: TextInputType.emailAddress,
          ),
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

/// Bottom sheet listing several geocoder matches for the user to choose from.
class _PlacePicker extends StatelessWidget {
  const _PlacePicker({required this.matches});
  final List<GeoPlace> matches;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Which one is it?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          for (final p in matches)
            ListTile(
              leading: const Icon(
                Icons.place_outlined,
                color: AppColors.accent,
              ),
              title: Text(p.shortAddress),
              subtitle: Text(
                p.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.pop(context, p),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final bool pinned;
  final String? label;
  final bool locating;
  final VoidCallback onTap;
  const _LocationTile({
    required this.pinned,
    required this.label,
    required this.locating,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = pinned ? AppColors.green : AppColors.accent;
    final text = locating
        ? 'Getting your location…'
        : pinned
        ? 'Pinned on the map ✓  ${label ?? ''}'
        : 'Or use my current location';
    return InkWell(
      onTap: locating ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(pinned ? Icons.location_on : Icons.my_location, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
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

enum _PinSource { none, address, gps, manual }

/// Small map showing where the church will appear, so mistakes are caught
/// before submitting. Tapping moves the pin.
class _PinPreview extends StatelessWidget {
  const _PinPreview({required this.point, required this.onMove});
  final LatLng point;
  final ValueChanged<LatLng> onMove;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            Container(color: const Color(0xFF05060A)),
            FlutterMap(
              // A new key re-centres the map whenever the pin changes.
              key: ValueKey('${point.latitude},${point.longitude}'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                onTap: (_, p) => onMove(p),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.theevangelist.the_evangelist',
                  maxNativeZoom: 16,
                ),
                TileLayer(
                  urlTemplate:
                      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
                  userAgentPackageName: 'com.theevangelist.the_evangelist',
                  maxNativeZoom: 16,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.church,
                        color: AppColors.green,
                        size: 32,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 6,
              bottom: 4,
              child: IgnorePointer(
                child: Text(
                  '© Esri, HERE, Garmin, © OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
