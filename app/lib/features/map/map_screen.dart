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
/// + area_stats() RPCs (coordinates are fuzzed server-side).
///
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
      onRefresh: () async => setState(() => _future = _load()),
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
            padding: const EdgeInsets.all(16),
            children: [
              _LiveMap(
                controller: _mapController,
                center: _center,
                evangelists: near,
                locating: _locating,
                onLocate: _useMyLocation,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('${stats['evangelists'] ?? 0}', 'Evangelists'),
                      _stat('${stats['outreaches_today'] ?? 0}', 'Outreaches'),
                      _stat('${stats['churches_nearby'] ?? 0}', 'Churches'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: const BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(height: 16),
              const Text(
                'Live near you',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (near.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No one evangelising near you right now — be the first.',
                    ),
                  ),
                )
              else
                ...near.map(
                  (e) => Card(
                    child: ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.accent.withValues(
                              alpha: 0.2,
                            ),
                            child: Text(e.fullName.characters.first),
                          ),
                          const Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 5,
                              backgroundColor: AppColors.green,
                            ),
                          ),
                        ],
                      ),
                      title: Text(e.fullName),
                      subtitle: Text(
                        '${(e.distanceM / 1000).toStringAsFixed(1)} km away',
                      ),
                      trailing: const Text('🟢 live'),
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

class _LiveMap extends StatelessWidget {
  const _LiveMap({
    required this.controller,
    required this.center,
    required this.evangelists,
    required this.locating,
    required this.onLocate,
  });

  final MapController controller;
  final LatLng center;
  final List<NearbyEvangelist> evangelists;
  final bool locating;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final pins = evangelists
        .where((e) => e.latitude != 0 || e.longitude != 0)
        .map(
          (e) => Marker(
            point: LatLng(e.latitude, e.longitude),
            width: 44,
            height: 44,
            child: Tooltip(
              message: e.fullName,
              child: const Icon(
                Icons.location_pin,
                color: AppColors.accent,
                size: 38,
              ),
            ),
          ),
        )
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 240,
        child: Stack(
          children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(initialCenter: center, initialZoom: 10),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.theevangelist.the_evangelist',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 28,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                    ...pins,
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
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
          ],
        ),
      ),
    );
  }
}
