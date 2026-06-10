import 'dart:convert';

import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/camera_checkin_feed_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeAuthService extends AuthService {
  FakeAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

void main() {
  group('CameraCheckinFeedService', () {
    test('fetches everyone feed from /feed/checkins by default', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          '${Config.apiBaseUrl}/feed/checkins?filter=everyone&limit=12',
        );
        expect(request.headers['Authorization'], 'token-123');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'checkin-1',
                'createdAt': '2026-06-09T08:30:00.000Z',
                'mediaId': 'media-1',
                'userId': 'user-1',
                'userName': 'Me',
                'placeId': 'place-1',
                'placeName': 'Cafe',
              },
            ],
            'pagination': {'nextCursor': 'cursor-1', 'hasMore': true},
          }),
          200,
        );
      });

      final service = CameraCheckinFeedService(
        FakeAuthService('token-123'),
        client: client,
      );
      final result = await service.fetchCheckins(
        audience: CameraFeedAudience.everyone(),
      );

      expect(result.items, hasLength(1));
      expect(result.nextCursor, 'cursor-1');
      expect(result.hasMore, isTrue);
    });

    test('fetches selected friend feed with friendId', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          '${Config.apiBaseUrl}/feed/checkins?filter=everyone&limit=12&friendId=friend-1',
        );
        return http.Response(
          jsonEncode({
            'data': <dynamic>[],
            'pagination': {'hasMore': false},
          }),
          200,
        );
      });

      final service = CameraCheckinFeedService(
        FakeAuthService('token-123'),
        client: client,
      );
      final result = await service.fetchCheckins(
        audience: CameraFeedAudience.friend(id: 'friend-1', label: 'Lan'),
      );

      expect(result.items, isEmpty);
    });

    test('fetches me feed with filter=me', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          '${Config.apiBaseUrl}/feed/checkins?filter=me&limit=12',
        );
        return http.Response(
          jsonEncode({
            'data': <dynamic>[],
            'pagination': {'hasMore': false},
          }),
          200,
        );
      });

      final service = CameraCheckinFeedService(
        FakeAuthService('token-123'),
        client: client,
      );
      final result = await service.fetchCheckins(audience: CameraFeedAudience.me());

      expect(result.items, isEmpty);
    });

    test('returns empty page without calling HTTP when token is missing', () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        return http.Response('{}', 200);
      });

      final service = CameraCheckinFeedService(FakeAuthService(null), client: client);
      final result = await service.fetchCheckins(
        audience: CameraFeedAudience.everyone(),
      );

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
      expect(called, isFalse);
    });
  });
}
