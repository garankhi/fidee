import 'dart:async';
import 'dart:convert';

import 'package:fidey_mobile/services/appsync_realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('FriendRealtimeEvent', () {
    test('parses all fields from GraphQL payload', () {
      final event = FriendRealtimeEvent.fromGraphqlData({
        'eventId': 'friendship_removed#user-2#user-1',
        'type': 'FRIENDSHIP_REMOVED',
        'targetUserId': 'user-2',
        'actorUserId': 'user-1',
        'relatedUserId': 'user-1',
        'actorName': 'Minh Nguyen',
        'actorUsername': 'minh',
        'actorAvatarUrl': 'https://cdn.example/minh.png',
        'createdAt': '2026-06-12T03:00:00.000Z',
      });

      expect(event.eventId, 'friendship_removed#user-2#user-1');
      expect(event.type, 'FRIENDSHIP_REMOVED');
      expect(event.targetUserId, 'user-2');
      expect(event.actorUserId, 'user-1');
      expect(event.relatedUserId, 'user-1');
      expect(event.actorName, 'Minh Nguyen');
      expect(event.actorUsername, 'minh');
      expect(event.actorAvatarUrl, 'https://cdn.example/minh.png');
      expect(event.createdAt, DateTime.parse('2026-06-12T03:00:00.000Z'));
    });
  });

  group('AppSyncRealtimeService', () {
    test(
      'builds realtime URI and generic subscription variables for the user sub',
      () {
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
                    base64.decode(realtimeUri.queryParameters['header']!),
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

        expect(
          header['host'],
          'abc123.appsync-api.ap-southeast-1.amazonaws.com',
        );
        expect(header['Authorization'], 'token-123');
        expect(realtimeUri.queryParameters['payload'], 'e30=');
        expect(startMessage['type'], 'start');
        expect(payloadData['variables'], {'targetUserId': 'user-sub-1'});
        expect(payloadData['query'], contains('onFriendRealtimeEvent'));
        expect(
          startMessage['payload']['extensions']['authorization']['Authorization'],
          'token-123',
        );
      },
    );

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

    test(
      'waits for connection_ack before starting generic friendship subscription',
      () async {
        final fakeChannel = _FakeWebSocketChannel();
        final service = AppSyncRealtimeService(
          getToken: () async => 'token-123',
          graphqlUrl:
              'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
          realtimeUrl:
              'wss://abc123.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql',
          region: 'ap-southeast-1',
          connect: (_, {protocols}) => fakeChannel,
        );

        final subscription = service
            .subscribeToFriendRealtimeEvents(targetUserId: 'user-sub-1')
            .listen((_) {});
        addTearDown(subscription.cancel);
        await Future<void>.delayed(Duration.zero);

        expect(fakeChannel.sentTypes, ['connection_init']);

        fakeChannel.receive({'type': 'connection_ack'});
        await Future<void>.delayed(Duration.zero);

        expect(fakeChannel.sentTypes, ['connection_init', 'start']);
        final startBody =
            jsonDecode(fakeChannel.sentMessages[1] as String)
                as Map<String, dynamic>;
        final payloadData =
            jsonDecode(startBody['payload']['data'] as String)
                as Map<String, dynamic>;
        expect(payloadData['query'], contains('onFriendRealtimeEvent'));
        expect(payloadData['query'], contains('actorUserId'));
        expect(payloadData['query'], contains('relatedUserId'));
      },
    );

    test(
      'emits generic friendship event data from the websocket stream',
      () async {
        final fakeChannel = _FakeWebSocketChannel();
        final service = AppSyncRealtimeService(
          getToken: () async => 'token-123',
          graphqlUrl:
              'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
          realtimeUrl:
              'wss://abc123.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql',
          region: 'ap-southeast-1',
          connect: (_, {protocols}) => fakeChannel,
        );

        final events = <FriendRealtimeEvent>[];
        final subscription = service
            .subscribeToFriendRealtimeEvents(targetUserId: 'user-sub-1')
            .listen(events.add);
        addTearDown(subscription.cancel);
        await Future<void>.delayed(Duration.zero);

        fakeChannel.receive({'type': 'connection_ack'});
        await Future<void>.delayed(Duration.zero);
        fakeChannel.receive({
          'type': 'data',
          'payload': {
            'data': {
              'onFriendRealtimeEvent': {
                'eventId': 'friendship_removed#user-sub-1#user-2',
                'type': 'FRIENDSHIP_REMOVED',
                'targetUserId': 'user-sub-1',
                'actorUserId': 'user-2',
                'relatedUserId': 'user-2',
                'actorName': 'Tran An',
                'actorUsername': 'tran',
                'actorAvatarUrl': '',
                'createdAt': '2026-06-12T03:00:00.000Z',
              },
            },
          },
        });
        await Future<void>.delayed(Duration.zero);

        expect(events.single.type, 'FRIENDSHIP_REMOVED');
        expect(events.single.actorUserId, 'user-2');
      },
    );
  });
}

class _FakeWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  final _sink = _FakeWebSocketSink();

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => 'graphql-ws';

  @override
  Future<void> get ready => Future<void>.value();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  List<String?> get sentTypes => _sink.sentMessages
      .map((message) => jsonDecode(message as String) as Map<String, dynamic>)
      .map((message) => message['type'] as String?)
      .toList(growable: false);

  List<dynamic> get sentMessages => _sink.sentMessages;

  void receive(Map<String, dynamic> message) {
    _incoming.add(jsonEncode(message));
  }
}

class _FakeWebSocketSink implements WebSocketSink {
  final sentMessages = <dynamic>[];
  final _done = Completer<void>();

  @override
  Future<void> get done => _done.future;

  @override
  void add(dynamic data) {
    sentMessages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final message in stream) {
      add(message);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}
