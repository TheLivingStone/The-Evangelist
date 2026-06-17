import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

/// Live map of evangelists. Uses the privacy-preserving nearby_evangelists()
/// + area_stats() RPCs (coordinates are fuzzed server-side).
///
/// NOTE: a full Google Map needs GOOGLE_MAPS_API_KEY + native config. Until
/// that key is provided, this renders the same data as a live list + stats,
/// so the feature is fully operational end-to-end against the backend.
class MapScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const MapScreen({super.key, this.embedded = false});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  // Default center (Atlanta) used for the area query until device GPS is wired.
  static const _lat = 33.749;
  static const _lng = -84.388;

  late Future<(List<NearbyEvangelist>, Map<String, dynamic>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(List<NearbyEvangelist>, Map<String, dynamic>)> _load() async {
    final repo = ref.read(mapRepoProvider);
    final near = await repo.nearbyEvangelists(_lat, _lng, radius: 50000);
    final stats = await repo.areaStats(_lat, _lng, radius: 50000);
    return (near, stats);
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
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              Center(child: Text('Error: ${snap.error}')),
            ]);
          }
          final (near, stats) = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MapPlaceholder(),
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
              const SizedBox(height: 16),
              const Text('Live near you',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              if (near.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                        'No one evangelising near you right now — be the first.'),
                  ),
                )
              else
                ...near.map((e) => Card(
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.2),
                              child: Text(e.fullName.characters.first),
                            ),
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                  radius: 5, backgroundColor: AppColors.green),
                            ),
                          ],
                        ),
                        title: Text(e.fullName),
                        subtitle: Text('${(e.distanceM / 1000).toStringAsFixed(1)} km away'),
                        trailing: const Text('🟢 live'),
                      ),
                    )),
            ],
          );
        },
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Map')), body: body);
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent)),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}

class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.accent.withValues(alpha: 0.2),
          AppColors.blue.withValues(alpha: 0.15),
        ]),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.public, size: 40, color: AppColors.accent),
            SizedBox(height: 8),
            Text('Live Evangelism Map',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Add a Google Maps key to render pins',
                style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
