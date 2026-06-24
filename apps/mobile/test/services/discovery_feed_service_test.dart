import 'dart:convert';

import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/discovery_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AuthService extends AuthService {
  _AuthService() : super(isTestMode: true);

  @override
  Future<String?> getToken() async => 'id-token';
}

void main() {
  test('searchPlaces encodes filters and parses pagination', () async {
    late Uri requestedUri;
    late String? authorization;
    final client = MockClient((request) async {
      requestedUri = request.url;
      authorization = request.headers['Authorization'];
      return http.Response(
        jsonEncode({
          'status': 'success',
          'data': [
            {
              'placeId': 'place-1',
              'name': 'Cà phê Chill',
              'category': 'cafe',
              'avgRating': 4.8,
              'ratingCount': 12,
              'checkinCount': 20,
              'lat': 10.77,
              'lng': 106.70,
              'distanceMeters': 350,
              'vibes': ['Dating', 'Chill'],
              'services': ['Wifi'],
            },
          ],
          'pagination': {
            'nextCursor': '2026-06-19T00:00:00.000Z',
            'hasMore': true,
          },
        }),
        200,
      );
    });
    final service = DiscoveryFeedService(_AuthService(), client: client);

    final page = await service.searchPlaces(
      lat: 10.77,
      lng: 106.70,
      query: 'cà phê',
      vibe: 'hen_ho',
      categories: const ['cafe', 'restaurant'],
      priceRanges: const ['*-50000', '100000-200000'],
      disRanges: const ['*-1000', '3000-5000'],
      sortOptions: const ['rating', 'price_asc'],
    );

    expect(authorization, 'id-token');
    expect(requestedUri.path, '/discovery/search');
    expect(requestedUri.queryParameters, containsPair('q', 'cà phê'));
    expect(requestedUri.queryParameters, containsPair('vibe', 'hen_ho'));
    expect(
      requestedUri.queryParameters,
      containsPair('category', 'cafe,restaurant'),
    );
    expect(
      requestedUri.queryParameters,
      containsPair('priceRange', '*-50000,100000-200000'),
    );
    expect(
      requestedUri.queryParameters,
      containsPair('disRange', '*-1000,3000-5000'),
    );
    expect(
      requestedUri.queryParameters,
      containsPair('sortBy', 'rating,price_asc'),
    );
    expect(page.places.single.vibes, ['Dating', 'Chill']);
    expect(page.places.single.services, ['Wifi']);
    expect(page.hasMore, isTrue);
  });
}
