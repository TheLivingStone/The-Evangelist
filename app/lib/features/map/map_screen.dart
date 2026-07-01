import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../churches/churches_screen.dart';

/// Live map of evangelists. Uses the privacy-preserving nearby_evangelists()
/// + area_stats() RPCs (coordinates are fuzzed server-side, so dots show
/// approximate positions — never a person's exact location).
///
/// Visual direction: a dark street map with people rendered as small glowing
/// dots. Tapping a dot slides up an info card with that person's public
/// profile.
class MapScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const MapScreen({super.key, this.embedded = false});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _fallbackCenter = LatLng(33.749, -84.388);

  final _mapController = MapController();
  LatLng _center = _fallbackCenter;
  bool _locating = false;
  NearbyEvangelist? _selected;
  late Future<(List<NearbyEvangelist>, Map<String, dynamic>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<NearbyEvangelist>, Map<String, dynamic>)> _load() async {
    final repo = ref.read(mapRepoProvider);
    final (near, stats) = await (
      repo.nearbyEvangelists(
        _center.latitude,
        _center.longitude,
        radius: 50000,
      ),
      repo.areaStats(_center.latitude, _center.longitude, radius: 50000),
    ).wait;
    return (near, stats);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Location services are turned off');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      _center = LatLng(position.latitude, position.longitude);
      _mapController.move(_center, 12);
      setState(() => _future = _load());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not use your location: $error')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => setState(() {
        _selected = null;
        _future = _load();
      }),
      child: FutureBuilder<(List<NearbyEvangelist>, Map<String, dynamic>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snap.hasError) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text('Error: ${snap.error}')),
              ],
            );
          }
          final (near, stats) = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(Dims.l),
            children: [
              _LiveMap(
                controller: _mapController,
                center: _center,
                evangelists: near,
                locating: _locating,
                selected: _selected,
                onLocate: _useMyLocation,
                onSelect: (e) => setState(() => _selected = e),
              ),
              const SizedBox(height: Dims.m),
              Surfaces.card(
                context,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat('${stats['evangelists'] ?? 0}', 'Evangelists'),
                    _stat('${stats['outreaches_today'] ?? 0}', 'Outreaches'),
                    _stat('${stats['churches_nearby'] ?? 0}', 'Churches'),
                  ],
                ),
              ),
              const SizedBox(height: Dims.m),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Dims.rSm),
                    ),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChurchesScreen()),
                  ),
                  icon: const Icon(Icons.church_outlined),
                  label: const Text(
                    'Find & register churches',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: Dims.l),
              const Text(
                'Live near you',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: Dims.s),
              if (near.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Dims.xxl),
                  child: Center(
                    child: Text(
                      'No one evangelising near you right now — be the first.',
                      style: TextStyle(color: Dims.muted(context)),
                    ),
                  ),
                )
              else
                ...near.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: Dims.s),
                    child: Surfaces.card(
                      context,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dims.m,
                        vertical: Dims.s,
                      ),
                      onTap: () {
                        setState(() => _selected = e);
                        _mapController.move(
                          LatLng(e.latitude, e.longitude),
                          13,
                        );
                      },
                      child: Row(
                        children: [
                          _Avatar(name: e.fullName),
                          const SizedBox(width: Dims.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${(e.distanceM / 1000).toStringAsFixed(1)} km away',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Dims.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _LiveBadge(),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: body,
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.accent,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12)),
    ],
  );
}

/// A small green "live" pill.
class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Dims.s, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.green.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(Dims.rPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        const Text(
          'live',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.green,
          ),
        ),
      ],
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.characters.first;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

class _LiveMap extends StatelessWidget {
  const _LiveMap({
    required this.controller,
    required this.center,
    required this.evangelists,
    required this.locating,
    required this.selected,
    required this.onLocate,
    required this.onSelect,
  });

  final MapController controller;
  final LatLng center;
  final List<NearbyEvangelist> evangelists;
  final bool locating;
  final NearbyEvangelist? selected;
  final VoidCallback onLocate;
  // Pass an evangelist to select it, or null to dismiss the card.
  final ValueChanged<NearbyEvangelist?> onSelect;

  @override
  Widget build(BuildContext context) {
    final dots = evangelists
        .where((e) => e.latitude != 0 || e.longitude != 0)
        .map(
          (e) => Marker(
            point: LatLng(e.latitude, e.longitude),
            width: 26,
            height: 26,
            child: _Dot(
              selected: selected?.userId == e.userId,
              onTap: () => onSelect(e),
            ),
          ),
        )
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(Dims.rLg),
      child: SizedBox(
        height: 280,
        child: Stack(
          children: [
            // Solid black underlay so any tile gaps read as black, not grey.
            Container(color: const Color(0xFF05060A)),
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 11,
                // Tapping empty map dismisses the selected card.
                onTap: (_, _) => onSelect(null),
              ),
              children: [
                // CARTO dark-matter tiles — a black/charcoal street map with
                // faint grey streets + labels. Free for reasonable use. Kept on
                // the simplest URL form (no {s} subdomain / {r} retina token),
                // which loads reliably on web and mobile alike.
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.theevangelist.the_evangelist',
                ),
                MarkerLayer(
                  markers: [
                    // The viewer's own location: a blue dot with a white ring.
                    Marker(
                      point: center,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                    ...dots,
                  ],
                ),
                const RichAttributionWidget(
                  showFlutterMapAttribution: false,
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap, © CARTO'),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 10,
              top: 10,
              child: FloatingActionButton.small(
                heroTag: null,
                onPressed: locating ? null : onLocate,
                tooltip: 'Use my location',
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: AppColors.blue,
                child: locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
            // Slide-up info card for the tapped person.
            if (selected != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _PersonCard(
                  key: ValueKey(selected!.userId),
                  person: selected!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A glowing dot representing one evangelist on the map.
class _Dot extends StatelessWidget {
  const _Dot({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 18.0 : 13.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.9 : 0.35),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.6),
                blurRadius: selected ? 14 : 8,
                spreadRadius: selected ? 2 : 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom info card that loads + shows the tapped person's public profile.
class _PersonCard extends ConsumerWidget {
  const _PersonCard({super.key, required this.person});
  final NearbyEvangelist person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(publicProfileProvider(person.userId));
    final km = (person.distanceM / 1000).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(Dims.rMd),
        border: Border.all(color: Dims.border(context), width: Dims.hairline),
      ),
      padding: const EdgeInsets.all(Dims.m),
      child: Row(
        children: [
          _Avatar(name: person.fullName),
          const SizedBox(width: Dims.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  person.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                profile.when(
                  data: (p) => Text(
                    _subtitle(p, km),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Dims.muted(context)),
                  ),
                  loading: () => Text(
                    '$km km away',
                    style: TextStyle(fontSize: 12, color: Dims.muted(context)),
                  ),
                  error: (_, _) => Text(
                    '$km km away',
                    style: TextStyle(fontSize: 12, color: Dims.muted(context)),
                  ),
                ),
              ],
            ),
          ),
          _LiveBadge(),
        ],
      ),
    );
  }

  String _subtitle(Profile? p, String km) {
    if (p == null) return '$km km away';
    final bits = <String>[
      if (p.ministry != null && p.ministry!.isNotEmpty) p.ministry!,
      if (p.church != null && p.church!.isNotEmpty) p.church!,
      if (p.city != null && p.city!.isNotEmpty) p.city!,
    ];
    final who = bits.isEmpty ? '' : '${bits.take(2).join(' · ')}  ·  ';
    return '$who$km km away';
  }
}
