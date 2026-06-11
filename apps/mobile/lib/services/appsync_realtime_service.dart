import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketConnector =
    WebSocketChannel Function(Uri uri, {Iterable<String>? protocols});

class FriendRealtimeEvent {
  final String type;
  final String eventId;
  final String targetUserId;
  final String actorUserId;
  final String relatedUserId;
  final String actorName;
  final String actorUsername;
  final String actorAvatarUrl;
  final DateTime createdAt;

  const FriendRealtimeEvent({
    required this.type,
    required this.eventId,
    required this.targetUserId,
    required this.actorUserId,
    required this.relatedUserId,
    required this.actorName,
    required this.actorUsername,
    required this.actorAvatarUrl,
    required this.createdAt,
  });

  factory FriendRealtimeEvent.fromGraphqlData(Map<String, dynamic> data) {
    return FriendRealtimeEvent(
      type: data['type'] as String? ?? 'FRIEND_REQUEST_RECEIVED',
      eventId: data['eventId'] as String? ?? '',
      targetUserId: data['targetUserId'] as String? ?? '',
      actorUserId: data['actorUserId'] as String? ?? '',
      relatedUserId: data['relatedUserId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? 'Một người bạn',
      actorUsername: data['actorUsername'] as String? ?? '',
      actorAvatarUrl: data['actorAvatarUrl'] as String? ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AppSyncRealtimeService {
  final Future<String?> Function() getToken;
  final String graphqlUrl;
  final String realtimeUrl;
  final String region;
  final WebSocketConnector _connect;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _socketSubscription;

  AppSyncRealtimeService({
    required this.getToken,
    required this.graphqlUrl,
    required this.realtimeUrl,
    required this.region,
    WebSocketConnector connect = WebSocketChannel.connect,
  }) : _connect = connect;

  Stream<FriendRealtimeEvent> subscribeToFriendRealtimeEvents({
    required String targetUserId,
  }) {
    final controller = StreamController<FriendRealtimeEvent>();
    unawaited(_connectSubscription(targetUserId, controller));
    return controller.stream;
  }

  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @visibleForTesting
  Uri buildRealtimeUriForTesting(String token) => _buildRealtimeUri(token);

  @visibleForTesting
  Map<String, dynamic> buildSubscriptionStartMessageForTesting({
    required String token,
    required String targetUserId,
  }) {
    return _buildSubscriptionStartMessage(
      token: token,
      targetUserId: targetUserId,
    );
  }

  Future<void> _connectSubscription(
    String targetUserId,
    StreamController<FriendRealtimeEvent> controller,
  ) async {
    final token = await getToken();
    if (token == null ||
        token.isEmpty ||
        graphqlUrl.isEmpty ||
        realtimeUrl.isEmpty) {
      await controller.close();
      return;
    }

    try {
      final channel = _connect(
        _buildRealtimeUri(token),
        protocols: ['graphql-ws'],
      );
      _channel = channel;
      await channel.ready;

      var subscriptionStarted = false;
      void startSubscription() {
        if (subscriptionStarted) return;
        subscriptionStarted = true;
        channel.sink.add(
          jsonEncode(
            _buildSubscriptionStartMessage(
              token: token,
              targetUserId: targetUserId,
            ),
          ),
        );
      }

      _socketSubscription = channel.stream.listen(
        (message) => _handleSocketMessage(
          message,
          controller,
          onConnectionAck: startSubscription,
        ),
        onError: controller.addError,
        onDone: controller.close,
      );
      channel.sink.add(jsonEncode({'type': 'connection_init'}));
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      await controller.close();
    }
  }

  Uri _buildRealtimeUri(String token) {
    final graphqlHost = Uri.parse(graphqlUrl).host;
    final header = _base64Json({'host': graphqlHost, 'Authorization': token});
    final payload = _base64Json(<String, dynamic>{});
    final uri = Uri.parse(realtimeUrl);
    if (!uri.hasScheme || uri.host.isEmpty) {
      throw StateError('AppSync realtimeUrl must be an absolute WebSocket URL');
    }

    return uri.replace(queryParameters: {'header': header, 'payload': payload});
  }

  Map<String, dynamic> _buildSubscriptionStartMessage({
    required String token,
    required String targetUserId,
  }) {
    final graphqlHost = Uri.parse(graphqlUrl).host;
    return {
      'id': 'friend-realtime-$targetUserId',
      'type': 'start',
      'payload': {
        'data': jsonEncode({
          'query': r'''
subscription OnFriendRealtimeEvent($targetUserId: ID!) {
  onFriendRealtimeEvent(targetUserId: $targetUserId) {
    eventId
    type
    targetUserId
    actorUserId
    relatedUserId
    actorName
    actorUsername
    actorAvatarUrl
    createdAt
  }
}
''',
          'variables': {'targetUserId': targetUserId},
        }),
        'extensions': {
          'authorization': {'host': graphqlHost, 'Authorization': token},
        },
      },
    };
  }

  void _handleSocketMessage(
    dynamic message,
    StreamController<FriendRealtimeEvent> controller, {
    required VoidCallback onConnectionAck,
  }) {
    final decoded = jsonDecode(message as String) as Map<String, dynamic>;
    final type = decoded['type'] as String?;
    if (type == 'connection_ack') {
      onConnectionAck();
    } else if (type == 'data') {
      final payload = decoded['payload'] as Map<String, dynamic>?;
      final data = payload?['data'] as Map<String, dynamic>?;
      final event = data?['onFriendRealtimeEvent'] as Map<String, dynamic>?;
      if (event != null) {
        controller.add(FriendRealtimeEvent.fromGraphqlData(event));
      }
    } else if (type == 'error' || type == 'connection_error') {
      controller.addError((decoded['payload'] ?? decoded) as Object);
    }
  }

  String _base64Json(Map<String, dynamic> value) {
    return base64.encode(utf8.encode(jsonEncode(value)));
  }
}
