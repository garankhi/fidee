import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/nearby_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenAuthService extends AuthService {
  @override
  Future<String?> getToken() async => 'test-token';
}

void main() {
  test(
    'fetchNearby calls nearby places with radius and without media id',
    () async {
      Uri? capturedUri;

      final service = NearbyService(
        _TokenAuthService(),
        client: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            '{"status":"success","metadata":{"source":"goong_places","has_goong_fallback":false,"total_results":0},"data":[]}',
            200,
          );
        }),
      );

      await service.fetchNearby(lat: 10.7738, lng: 106.7035, radius: 1000);

      expect(capturedUri?.path, '/places/nearby');
      expect(capturedUri?.queryParameters['lat'], '10.7738');
      expect(capturedUri?.queryParameters['lng'], '106.7035');
      expect(capturedUri?.queryParameters['radius'], '1000');
      expect(capturedUri?.queryParameters.containsKey('media_id'), isFalse);
    },
  );

  test('fetchNearby sends a trimmed spot search query', () async {
    Uri? capturedUri;
    final service = NearbyService(
      _TokenAuthService(),
      client: MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          '{"status":"success","metadata":{"source":"local_db","has_goong_fallback":false,"total_results":0},"data":[]}',
          200,
        );
      }),
    );

    await service.fetchNearby(
      lat: 10.7738,
      lng: 106.7035,
      radius: 1000,
      query: '  coffee  ',
    );

    expect(capturedUri?.queryParameters['q'], 'coffee');
  });

  test(
    'fetchNearby throws instead of returning an empty fallback on API error',
    () async {
      final service = NearbyService(
        _TokenAuthService(),
        client: MockClient(
          (request) async => http.Response('Unauthorized', 401),
        ),
      );

      expect(
        service.fetchNearby(lat: 10.7738, lng: 106.7035, radius: 1000),
        throwsA(isA<NearbyException>()),
      );
    },
  );
}
