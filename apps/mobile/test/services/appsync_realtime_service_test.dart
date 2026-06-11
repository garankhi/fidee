import 'dart:convert';

import 'package:fidee_mobile/services/appsync_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FriendRequestRealtimeEvent', () {
    test('parses all fields from GraphQL payload', () {
      final event = FriendRequestRealtimeEvent.fromGraphqlData({
        'eventId': 'friend_request#user-1#user-2',
        'targetUserId': 'user-2',
        'requesterId': 'user-1',
        'requesterName': 'Minh Nguyen',
        'requesterUsername': 'minh',
        'requesterAvatarUrl': 'https://cdn.example/minh.png',
        'createdAt': '2026-06-11T03:00:00.000Z',
      });

      expect(event.eventId, 'friend_request#user-1#user-2');
      expect(event.targetUserId, 'user-2');
      expect(event.requesterId, 'user-1');
      expect(event.requesterName, 'Minh Nguyen');
      expect(event.requesterUsername, 'minh');
      expect(event.requesterAvatarUrl, 'https://cdn.example/minh.png');
      expect(event.createdAt, DateTime.parse('2026-06-11T03:00:00.000Z'));
    });
  });

  group('AppSyncRealtimeService', () {
    test('builds realtime URI and subscription variables for the user sub', () {
      final service = AppSyncRealtimeService(
        getToken: () async => 'token-123',
        graphqlUrl:
            'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
        realtimeUrl:
            'wss://abc123.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql',
        region: 'ap-southeast-1',
      );

      final realtimeUri = service.buildRealtimeUriForTesting('token-123');
      final header =
          jsonDecode(
                utf8.decode(
                  base64Url.decode(
                    base64Url.normalize(realtimeUri.queryParameters['header']!),
                  ),
                ),
              )
              as Map<String, dynamic>;
      final startMessage = service.buildSubscriptionStartMessageForTesting(
        token: 'token-123',
        targetUserId: 'user-sub-1',
      );
      final payloadData =
          jsonDecode(startMessage['payload']['data'] as String)
              as Map<String, dynamic>;

      expect(header['host'], 'abc123.appsync-api.ap-southeast-1.amazonaws.com');
      expect(header['Authorization'], 'token-123');
      expect(startMessage['type'], 'start');
      expect(payloadData['variables'], {'targetUserId': 'user-sub-1'});
      expect(
        startMessage['payload']['extensions']['authorization']['Authorization'],
        'token-123',
      );
    });

    test('rejects realtime config that is not an absolute URL', () {
      final service = AppSyncRealtimeService(
        getToken: () async => 'token-123',
        graphqlUrl:
            'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
        realtimeUrl: 'xjx2dmbn4jgjpgrfhgvxc7ujte',
        region: 'ap-southeast-1',
      );

      expect(
        () => service.buildRealtimeUriForTesting('token-123'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
