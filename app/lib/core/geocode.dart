import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as native;
import 'package:http/http.dart' as http;

/// One address match from the geocoder.
class GeoPlace {
  const GeoPlace({
    required this.label,
    required this.lat,
    required this.lng,
    this.street,
    this.city,
    this.region,
    this.postcode,
  });

  /// Full display name as the geocoder wrote it.
  final String label;
  final double lat;
  final double lng;

  /// House number + road, e.g. "123 Peachtree St".
  final String? street;
  final String? city;

  /// State / province.
  final String? region;
  final String? postcode;

  /// "123 Peachtree St, Atlanta, Georgia" — what we show once a place is
  /// pinned. Falls back to the geocoder's own label.
  String get shortAddress {
    final parts = [
      street,
      city,
      region,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? label : parts.join(', ');
  }

  /// Parses one result row from Nominatim (`format=jsonv2&addressdetails=1`).
  factory GeoPlace.fromNominatim(Map<String, dynamic> m) {
    final a = (m['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final number = pick(['house_number']);
    final road = pick(['road', 'pedestrian', 'footway']);
    final street = [number, road].whereType<String>().join(' ').trim();
    return GeoPlace(
      label: (m['display_name'] ?? '').toString(),
      lat: double.parse(m['lat'].toString()),
      lng: double.parse(m['lon'].toString()),
      street: street.isEmpty ? null : street,
      city: pick([
        'city',
        'town',
        'village',
        'hamlet',
        'municipality',
        'county',
      ]),
      region: pick(['state', 'province', 'region']),
      postcode: pick(['postcode']),
    );
  }

  /// Builds a place from the platform geocoder (Apple on iOS, Google on
  /// Android) for the given coordinates.
  factory GeoPlace.fromPlacemark(native.Placemark m, double lat, double lng) {
    String? clean(String? s) =>
        (s == null || s.trim().isEmpty) ? null : s.trim();
    final street = [
      clean(m.subThoroughfare),
      clean(m.thoroughfare),
    ].whereType<String>().join(' ');
    final city = clean(m.locality) ?? clean(m.subAdministrativeArea);
    final label = [
      clean(m.name),
      street.isEmpty ? null : street,
      city,
      clean(m.administrativeArea),
      clean(m.postalCode),
    ].whereType<String>().toSet().join(', ');
    return GeoPlace(
      label: label,
      lat: lat,
      lng: lng,
      street: street.isEmpty ? null : street,
      city: city,
      region: clean(m.administrativeArea),
      postcode: clean(m.postalCode),
    );
  }
}

/// Address ⇄ coordinates.
///
/// On a phone this uses the platform geocoder first: Apple's on iOS and
/// Google's on Android. Both know US street addresses down to the house
/// number and need no API key. OpenStreetMap's Nominatim is the fallback (and
/// the only option on the web); it is free and keyless but rate-limited to
/// about one request per second and patchy on house numbers, so it is only
/// ever called from the church forms on a user tap.
class Geocoder {
  Geocoder({http.Client? client, bool? useNative})
    : _client = client ?? http.Client(),
      _useNative = useNative ?? !kIsWeb;

  final http.Client _client;
  final bool _useNative;

  // Created on first use only, so tests (and the web) never touch the
  // platform channel.
  late final native.Geocoding _nativeGeocoder = native.Geocoding();

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _headers = {
    // Nominatim's usage policy requires an identifying user agent.
    'User-Agent': 'GoAndTell/1.0 (church registration)',
    'Accept-Language': 'en',
  };
  static const _timeout = Duration(seconds: 12);

  /// Free-text search, e.g. "7403 Boston Blvd, Springfield VA". Best results
  /// come from a street address plus city.
  Future<List<GeoPlace>> search(String query, {int limit = 5}) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    if (_useNative) {
      final hits = await _nativeSearch(q, limit);
      if (hits.isNotEmpty) return hits;
    }
    return _nominatimSearch(q, limit);
  }

  /// Coordinates → nearest street address. Returns null when nothing is
  /// known for the point (open water, remote land) or every lookup fails.
  Future<GeoPlace?> reverse(double lat, double lng) async {
    if (_useNative) {
      try {
        final marks = await _nativeGeocoder
            .placemarkFromCoordinates(lat, lng)
            .timeout(_timeout);
        if (marks.isNotEmpty) {
          return GeoPlace.fromPlacemark(marks.first, lat, lng);
        }
      } catch (_) {
        // Fall through to Nominatim.
      }
    }
    return _nominatimReverse(lat, lng);
  }

  Future<List<GeoPlace>> _nativeSearch(String q, int limit) async {
    try {
      final locs = await _nativeGeocoder
          .locationFromAddress(q)
          .timeout(_timeout);
      final out = <GeoPlace>[];
      for (final l in locs.take(limit)) {
        GeoPlace? place;
        try {
          final marks = await _nativeGeocoder
              .placemarkFromCoordinates(l.latitude, l.longitude)
              .timeout(_timeout);
          if (marks.isNotEmpty) {
            place = GeoPlace.fromPlacemark(
              marks.first,
              l.latitude,
              l.longitude,
            );
          }
        } catch (_) {
          // Coordinates without a readable address are still a valid pin.
        }
        out.add(place ?? GeoPlace(label: q, lat: l.latitude, lng: l.longitude));
      }
      return out;
    } catch (_) {
      // NoResultFoundException, no network, or platform not supported.
      return const [];
    }
  }

  Future<List<GeoPlace>> _nominatimSearch(String q, int limit) async {
    final uri = Uri.parse('$_base/search').replace(
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limit',
      },
    );
    final res = await _client.get(uri, headers: _headers).timeout(_timeout);
    if (res.statusCode != 200) {
      throw Exception('Address lookup failed (${res.statusCode})');
    }
    final rows = jsonDecode(res.body) as List;
    return rows
        .map((r) => GeoPlace.fromNominatim(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<GeoPlace?> _nominatimReverse(double lat, double lng) async {
    final uri = Uri.parse('$_base/reverse').replace(
      queryParameters: {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      },
    );
    try {
      final res = await _client.get(uri, headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) return null;
      final m = jsonDecode(res.body);
      if (m is! Map || m['error'] != null || m['lat'] == null) return null;
      return GeoPlace.fromNominatim(Map<String, dynamic>.from(m));
    } catch (_) {
      return null;
    }
  }
}
