import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class PersonProfileScreen extends ConsumerStatefulWidget {
  final Contact contact;
  const PersonProfileScreen({super.key, required this.contact});
  @override
  ConsumerState<PersonProfileScreen> createState() =>
      _PersonProfileScreenState();
}

class _PersonProfileScreenState extends ConsumerState<PersonProfileScreen> {
  late Contact c = widget.contact;

  Future<void> _changeStatus(String s) async {
    await ref.read(contactsRepoProvider).update(c.id, {'status': s});
    setState(() => c = Contact.fromMap({
          'id': c.id,
          'owner_id': c.ownerId,
          'first_name': c.firstName,
          'last_name': c.lastName,
          'phone': c.phone,
          'email': c.email,
          'city': c.city,
          'met_location': c.metLocation,
          'date_met': c.dateMet.toIso8601String(),
          'status': s,
          'notes': c.notes,
          'next_followup_at':
              c.nextFollowupAt?.toIso8601String().substring(0, 10),
          'tags': c.tags,
          'visible_to_church': c.visibleToChurch,
          'met_lat': c.metLat,
          'met_lng': c.metLng,
          'created_at': c.createdAt.toIso8601String(),
        }));
    // connecting to church is itself an outreach activity
    if (s == 'connected_to_church') {
      await ref.read(activityRepoProvider).log('church_connection',
          contactId: c.id);
      ref.invalidate(myProfileProvider);
    }
  }

  Future<void> _logConversation() async {
    await ref.read(activityRepoProvider).log('conversation', contactId: c.id);
    ref.invalidate(myProfileProvider);
    ref.invalidate(monthCountsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💬 Conversation logged')));
    }
  }

  Future<void> _logFollowup() async {
    await ref.read(activityRepoProvider).log('followup', contactId: c.id);
    ref.invalidate(myProfileProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('📩 Follow-up logged')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(c.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: Text(c.firstName.characters.first,
                  style: const TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 12),
          Center(
              child: Text(c.displayName,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800))),
          Center(child: Text(prettyStatus(c.status))),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _quick(Icons.chat_bubble, 'Log Conv.', _logConversation),
              _quick(Icons.mark_email_read, 'Follow-up', _logFollowup),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Details',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (c.phone != null) _row(Icons.phone, c.phone!),
                  if (c.email != null) _row(Icons.email, c.email!),
                  if (c.metLocation != null)
                    _row(Icons.place, 'Met at ${c.metLocation}'),
                  _row(
                    Icons.event,
                    'Met ${DateFormat("MMM d, yyyy 'at' h:mm a").format(c.createdAt)}',
                  ),
                  if (c.notes != null) _row(Icons.notes, c.notes!),
                  if (c.metLat != null && c.metLng != null) ...[
                    const SizedBox(height: 8),
                    _MetLocationMap(lat: c.metLat!, lng: c.metLng!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spiritual journey',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: spiritualStatuses
                        .map((s) => ChoiceChip(
                              label: Text(prettyStatus(s)),
                              selected: c.status == s,
                              selectedColor:
                                  AppColors.green.withValues(alpha: 0.25),
                              onSelected: (_) => _changeStatus(s),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quick(IconData icon, String label, VoidCallback onTap) => Column(
        children: [
          IconButton.filled(
            onPressed: onTap,
            icon: Icon(icon),
            style: IconButton.styleFrom(
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                foregroundColor: AppColors.accent),
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}

/// A small, mostly-static map pinning where a contact was met — a quiet
/// visual reminder alongside the free-text "met at" description. Reuses the
/// same CARTO dark tiles as the live map screen.
class _MetLocationMap extends StatelessWidget {
  final double lat;
  final double lng;
  const _MetLocationMap({required this.lat, required this.lng});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            Container(color: const Color(0xFF05060A)),
            FlutterMap(
              options: MapOptions(initialCenter: point, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.theevangelist.the_evangelist',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 26,
                      height: 26,
                      child: const Icon(
                        Icons.place,
                        color: AppColors.accent,
                        size: 26,
                      ),
                    ),
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
          ],
        ),
      ),
    );
  }
}
