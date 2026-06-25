import 'dart:convert';

import 'package:fidey_mobile/services/goong_geocoding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reverseGeocode returns the first formatted address from Goong', () async {
    final service = GoongGeocodingService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        expect(request.url.path, '/Geocode');
        expect(request.url.queryParameters['latlng'], '10.1,106.1');
        expect(request.url.queryParameters['api_key'], 'test-key');
        return http.Response(
          jsonEncode({
            'results': [
              {'formatted_address': '12 Nguyen Hue, TP.HCM'},
            ],
          }),
          200,
        );
      }),
    );

    expect(
      await service.reverseGeocode(lat: 10.1, lng: 106.1),
      '12 Nguyen Hue, TP.HCM',
    );
  });

  test('validateAddressNear reports far addresses by comparing coordinates', () async {
    final service = GoongGeocodingService(
      apiKey: 'test-key',
      farDistanceMeters: 200,
      client: MockClient((request) async {
        expect(request.url.path, '/Geocode');
        expect(request.url.queryParameters['address'], '91 Trung Kinh');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'geometry': {
                  'location': {'lat': 10.2, 'lng': 106.2},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await service.validateAddressNear(
      address: '91 Trung Kinh',
      lat: 10.1,
      lng: 106.1,
    );

    expect(result, isNotNull);
    expect(result!.isFarFromCurrentLocation, isTrue);
    expect(result.distanceMeters, greaterThan(200));
  });

  test('returns null without an API key', () async {
    final service = GoongGeocodingService(apiKey: '');

    expect(await service.reverseGeocode(lat: 10.1, lng: 106.1), isNull);
  });
}
