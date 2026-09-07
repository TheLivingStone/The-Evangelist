import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/glass.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../churches/churches_screen.dart';
import '../../core/coach_marks.dart';

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
  Church? _selectedChurch;
  late Future<(List<NearbyEvangelist>, Map<String, dynamic>, List<Church>)>
  _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Centre on the user straight away; the fallback city is only for people
    // who decline location. Silent: no error toast on first open.
    _useMyLocation(silent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      CoachMarks.show(
        context,
        id: 'churches',
        target: CoachTargets.churchesButton,
        title: 'Churches near you',
        text:
            'Church icons on the map are churches taking part. Join your home '
            'church here, or register it so our team can verify it.',
        delay: const Duration(milliseconds: 1500),
      );
    });
  }

  Future<(List<NearbyEvangelist>, Map<String, dynamic>, List<Church>)>
  _load() async {
    final repo = ref.read(mapRepoProvider);
    final churchesRepo = ref.read(churchesRepoProvider);
    final (near, stats, churches) = await (
      repo.nearbyEvangelists(
        _center.latitude,
        _center.longitude,
        radius: 50000,
      ),
      repo.areaStats(_center.latitude, _center.longitude, radius: 50000),
      // Church pins decorate the map; a directory hiccup must never hide the
      // people on it, so a failure just means no pins this load.
      churchesRepo
          .nearby(_center.latitude, _center.longitude, radius: 50000)
          .catchError((Object _) => <Church>[]),
    ).wait;
    return (near, stats, churches);
  }

  Future<void> _useMyLocation({bool silent = false}) async {
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
      try {
        _mapController.move(_center, 12);
      } catch (_) {
        // Map not built yet (still loading); it opens at _center anyway.
      }
      setState(() => _future = _load());
    } catch (error) {
      if (!mounted || silent) return;
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
        _selectedChurch = null;
        _future = _load();
      }),
      child: FutureBuilder<(List<NearbyEvangelist>, Map<String, dynamic>, List<Church>)>(
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
          final (near, stats, churches) = snap.data!;
          // Content scrolls beneath the glass app bar / tab bar; this context
          // sits inside the Scaffold body, so the insets include both.
          final inset = MediaQuery.paddingOf(context);
          return ListView(
            padding: EdgeInsets.fromLTRB(
              Dims.gutter(context),
              inset.top + Dims.l,
              Dims.gutter(context),
              inset.bottom + Dims.l,
            ),
            children: [
              _LiveMap(
                controller: _mapController,
                center: _center,
                evangelists: near,
                churches: churches,
                locating: _locating,
                selected: _selected,
                selectedChurch: _selectedChurch,
                onLocate: _useMyLocation,
                onSelect: (e) => setState(() {
                  _selected = e;
                  if (e != null) _selectedChurch = null;
                }),
                onSelectChurch: (c) => setState(() {
                  _selectedChurch = c;
                  if (c != null) _selected = null;
                }),
              ),
              const SizedBox(height: Dims.s),
              const _Legend(),
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
                key: CoachTargets.churchesButton,
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
                        setState(() {
                          _selected = e;
                          _selectedChurch = null;
                        });
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
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('Map')),
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
    required this.churches,
    required this.locating,
    required this.selected,
    required this.selectedChurch,
    required this.onLocate,
    required this.onSelect,
    required this.onSelectChurch,
  });

  final MapController controller;
  final LatLng center;
  final List<NearbyEvangelist> evangelists;
  final List<Church> churches;
  final bool locating;
  final NearbyEvangelist? selected;
  final Church? selectedChurch;
  final VoidCallback onLocate;
  // Pass an evangelist to select it, or null to dismiss the card.
  final ValueChanged<NearbyEvangelist?> onSelect;
  // Pass a church to select it, or null to dismiss the card.
  final ValueChanged<Church?> onSelectChurch;

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
    // Church pins sit under the people dots so a live evangelist standing at
    // a church is never hidden.
    final pins = churches
        .where((c) => c.latitude != null && c.longitude != null)
        .map(
          (c) => Marker(
            point: LatLng(c.latitude!, c.longitude!),
            width: 34,
            height: 34,
            child: _ChurchPin(
              verified: c.isVerified,
              selected: selectedChurch?.id == c.id,
              onTap: () => onSelectChurch(c),
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
                onTap: (_, _) {
                  onSelect(null);
                  onSelectChurch(null);
                },
              ),
              children: [
                // CARTO dark-matter tiles — a black/charcoal street map with
                // faint grey streets + labels. Free for reasonable use. Kept on
                // the simplest URL form (no {s} subdomain / {r} retina token),
                // which loads reliably on web and mobile alike.
                // CARTO's public basemaps now watermark tiles "API KEY
                // REQUIRED". Esri's World Dark Gray canvas is served without
                // a key (attribution required, shown below) and matches the
                // dark UI. Base = streets/water; Reference = place names.
                ColorFiltered(
                  // The Esri canvas is mid-grey; pull it toward the app black.
                  colorFilter: const ColorFilter.mode(
                    Color(0x8A000000),
                    BlendMode.darken,
                  ),
                  child: Stack(
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName:
                            'com.theevangelist.the_evangelist',
                        maxNativeZoom: 16,
                      ),
                      TileLayer(
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName:
                            'com.theevangelist.the_evangelist',
                        maxNativeZoom: 16,
                      ),
                    ],
                  ),
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
                    ...pins,
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
              right: 6,
              bottom: 4,
              child: IgnorePointer(
                child: Text(
                  '© Esri, HERE, Garmin, © OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 8.5,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ),
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
            // Slide-up info card for the tapped person or church.
            if (selected != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _PersonCard(
                  key: ValueKey(selected!.userId),
                  person: selected!,
                ),
              )
            else if (selectedChurch != null)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: _ChurchMapCard(
                  key: ValueKey(selectedChurch!.id),
                  church: selectedChurch!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A glowing dot representing one evangelist on the map.
/// A church on the map. Verified (vetted by the team) churches glow green;
/// churches still under review are dimmed so nobody is sent there yet.
class _ChurchPin extends StatelessWidget {
  const _ChurchPin({
    required this.verified,
    required this.selected,
    required this.onTap,
  });
  final bool verified;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.green : Colors.white54;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: selected ? 32 : 26,
          height: selected ? 32 : 26,
          decoration: BoxDecoration(
            color: const Color(0xFF05060A),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : color,
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: verified
                ? [
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: 0.55),
                      blurRadius: selected ? 14 : 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(Icons.church, size: selected ? 18 : 15, color: color),
        ),
      ),
    );
  }
}

/// Bottom info card for a tapped church; tapping it opens the directory.
class _ChurchMapCard extends StatelessWidget {
  const _ChurchMapCard({super.key, required this.church});
  final Church church;

  @override
  Widget build(BuildContext context) {
    final km = church.distanceM == null
        ? null
        : (church.distanceM! / 1000).toStringAsFixed(1);
    final subtitle = [
      if (church.city != null && church.city!.isNotEmpty) church.city!,
      if (km != null) '$km km away',
    ].join('  ·  ');
    final (label, color, icon) = church.isVerified
        ? ('Verified', AppColors.green, Icons.verified)
        : ('Pending review', Colors.white54, Icons.hourglass_top);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Dims.rMd),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChurchesScreen()),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(Dims.rMd),
            border: Border.all(
              color: Dims.border(context),
              width: Dims.hairline,
            ),
          ),
          padding: const EdgeInsets.all(Dims.m),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.church, color: color, size: 20),
              ),
              const SizedBox(width: Dims.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      church.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle.isEmpty ? 'Tap to open the directory' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Dims.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Dims.s),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the map's symbols mean.
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11, color: Dims.muted(context));
    Widget dot(Color color) => Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    Widget item(Widget symbol, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        symbol,
        const SizedBox(width: 5),
        Text(label, style: style),
      ],
    );
    return Wrap(
      spacing: Dims.m,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        item(dot(AppColors.blue), 'You'),
        item(dot(AppColors.accent), 'Evangelising now'),
        item(
          const Icon(Icons.church, size: 13, color: AppColors.green),
          'Verified church',
        ),
        item(
          const Icon(Icons.church, size: 13, color: Colors.white54),
          'Under review',
        ),
      ],
    );
  }
}

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
