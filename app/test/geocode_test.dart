import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:the_evangelist/core/geocode.dart';

void main() {
  const row = {
    'lat': '33.7490',
    'lon': '-84.3880',
    'display_name':
        '10 Peachtree St NE, Atlanta, Fulton County, Georgia, 30303, United States',
    'address': {
      'house_number': '10',
      'road': 'Peachtree St NE',
      'city': 'Atlanta',
      'state': 'Georgia',
      'postcode': '30303',
    },
  };

  test('parses a Nominatim row into street, city and coordinates', () {
    final p = GeoPlace.fromNominatim(Map<String, dynamic>.from(row));
    expect(p.street, '10 Peachtree St NE');
    expect(p.city, 'Atlanta');
    expect(p.region, 'Georgia');
    expect(p.lat, closeTo(33.749, 1e-6));
    expect(p.lng, closeTo(-84.388, 1e-6));
    expect(p.shortAddress, '10 Peachtree St NE, Atlanta, Georgia');
  });

  test('falls back to town/village and the label when parts are missing', () {
    final p = GeoPlace.fromNominatim({
      'lat': '1',
      'lon': '2',
      'display_name': 'Somewhere',
      'address': {'village': 'Smallville'},
    });
    expect(p.street, isNull);
    expect(p.city, 'Smallville');
    expect(p.shortAddress, 'Smallville');
    expect(
      GeoPlace.fromNominatim({
        'lat': '1',
        'lon': '2',
        'display_name': 'X',
      }).shortAddress,
      'X',
    );
  });

  test('search sends an identifying user agent and parses results', () async {
    late http.Request seen;
    final client = MockClient((req) async {
      seen = req;
      return http.Response(jsonEncode([row]), 200);
    });
    final results = await Geocoder(
      client: client,
      useNative: false,
    ).search('10 Peachtree St');
    expect(results, hasLength(1));
    expect(results.single.city, 'Atlanta');
    expect(seen.url.host, 'nominatim.openstreetmap.org');
    expect(seen.url.queryParameters['q'], '10 Peachtree St');
    expect(seen.url.queryParameters['addressdetails'], '1');
    expect(seen.headers['User-Agent'], contains('GoAndTell'));
  });

  test('search skips the network for an empty query', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('[]', 200);
    });
    expect(
      await Geocoder(client: client, useNative: false).search('   '),
      isEmpty,
    );
    expect(calls, 0);
  });

  test('reverse returns null on an error body or a failed request', () async {
    final errorClient = MockClient(
      (_) async =>
          http.Response(jsonEncode({'error': 'Unable to geocode'}), 200),
    );
    expect(
      await Geocoder(client: errorClient, useNative: false).reverse(0, 0),
      isNull,
    );
    final downClient = MockClient((_) async => http.Response('nope', 503));
    expect(
      await Geocoder(client: downClient, useNative: false).reverse(0, 0),
      isNull,
    );
    final okClient = MockClient(
      (_) async => http.Response(jsonEncode(row), 200),
    );
    expect(
      (await Geocoder(
        client: okClient,
        useNative: false,
      ).reverse(33.7, -84.3))?.city,
      'Atlanta',
    );
  });
}
