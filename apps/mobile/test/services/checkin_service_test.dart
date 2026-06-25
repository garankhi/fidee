import 'dart:convert';

import 'package:fidey_mobile/config.dart';
import 'package:fidey_mobile/models/camera_share_audience.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/checkin_service.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenAuthService extends AuthService {
  _TokenAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

void main() {
  test('posts direct audience to /check-ins', () async {
    final service = CheckinService(
      _TokenAuthService('token-123'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/check-ins');
        expect(request.headers['Authorization'], 'token-123');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['place_id'], 'place-1');
        expect(body['media_id'], 'media-1');
        expect(body['visibility'], 'FRIENDS');
        expect(body['audience'], {
          'type': 'DIRECT',
          'friendIds': ['friend-1', 'friend-2'],
        });
        return http.Response(
          '{"status":"success","data":{"id":"checkin-1","created_at":"2026-06-12T01:00:00.000Z"}}',
          201,
        );
      }),
    );

    final result = await service.createCheckin(
      placeId: 'place-1',
      mediaId: 'media-1',
      gpsLat: 10.7738,
      gpsLng: 106.7035,
      audience: CameraShareAudience.friends(const <FriendProfile>[
        FriendProfile(
          id: 'friend-1',
          name: 'Test Api',
          handle: 'testapi@fidee.com',
        ),
        FriendProfile(id: 'friend-2', name: 'Minh Nguyen', handle: 'minh'),
      ]),
    );

    expect(result.checkinId, 'checkin-1');
    expect(result.createdAt, '2026-06-12T01:00:00.000Z');
  });

  test('posts media type for video check-ins', () async {
    final service = CheckinService(
      _TokenAuthService('token-123'),
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['media_type'], 'VIDEO');
        return http.Response(
          '{"status":"success","data":{"id":"checkin-video","created_at":"2026-06-12T01:00:00.000Z"}}',
          201,
        );
      }),
    );

    final result = await service.createCheckin(
      placeId: 'place-1',
      mediaId: 'media-video-1',
      mediaType: 'VIDEO',
      gpsLat: 10.7738,
      gpsLng: 106.7035,
      audience: CameraShareAudience.allFriends(),
    );

    expect(result.checkinId, 'checkin-video');
  });

  test('throws without posting when auth token is missing', () async {
    var called = false;
    final service = CheckinService(
      _TokenAuthService(null),
      client: MockClient((request) async {
        called = true;
        return http.Response('{}', 201);
      }),
    );

    expect(
      () => service.createCheckin(
        placeId: 'place-1',
        mediaId: 'media-1',
        gpsLat: 10.7738,
        gpsLng: 106.7035,
        audience: CameraShareAudience.allFriends(),
      ),
      throwsA(isA<CheckinException>()),
    );
    expect(called, isFalse);
  });
}
