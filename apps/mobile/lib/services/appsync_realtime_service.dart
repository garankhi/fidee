import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef WebSocketConnector = WebSocketChannel Function(
  Uri uri, {
  Iterable<String>? protocols,
});

class FriendRequestRealtimeEvent {
  final String eventId;
  final String targetUserId;
  final String requesterId;
  final String requesterName;
  final String requesterUsername;
  final String requesterAvatarUrl;
  final DateTime createdAt;

  const FriendRequestRealtimeEvent({
    required this.eventId,
    required this.targetUserId,
    required this.requesterId,
    required this.requesterName,
    required this.requesterUsername,
    required this.requesterAvatarUrl,
    required this.createdAt,
  });

  factory FriendRequestRealtimeEvent.fromGraphqlData(Map<String, dynamic> data) {
    return FriendRequestRealtimeEvent(
      eventId: data['eventId'] as String? ?? '',
      targetUserId: data['targetUserId'] as String? ?? '',
      requesterId: data['requesterId'] as String? ?? '',
      requesterName: data['requesterName'] as String? ?? 'Một người bạn',
      requesterUsername: data['requesterUsername'] as String? ?? '',
      requesterAvatarUrl: data['requesterAvatarUrl'] as String? ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now(),
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

  static String deriveRealtimeUrl(String graphqlUrl) {
    return graphqlUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('appsync-api', 'appsync-realtime-api');
  }

  Stream<FriendRequestRealtimeEvent> subscribeToFriendRequests({required String targetUserId}) {
    final controller = StreamController<FriendRequestRealtimeEvent>();
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
    return _buildSubscriptionStartMessage(token: token, targetUserId: targetUserId);
  }

  Future<void> _connectSubscription(
    String targetUserId,
    StreamController<FriendRequestRealtimeEvent> controller,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty || graphqlUrl.isEmpty) {
      await controller.close();
      return;
    }

    final effectiveRealtimeUrl = realtimeUrl.isEmpty ? deriveRealtimeUrl(graphqlUrl) : realtimeUrl;
    if (effectiveRealtimeUrl.isEmpty) {
      await controller.close();
      return;
    }

    try {
      final channel = _connect(_buildRealtimeUri(token, effectiveRealtimeUrl), protocols: ['graphql-ws']);
      _channel = channel;
      await channel.ready;
      channel.sink.add(jsonEncode({'type': 'connection_init'}));
      channel.sink.add(
        jsonEncode(_buildSubscriptionStartMessage(token: token, targetUserId: targetUserId)),
      );

      _socketSubscription = channel.stream.listen(
        (message) => _handleSocketMessage(message, controller),
        onError: controller.addError,
        onDone: controller.close,
      );
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      await controller.close();
    }
  }

  Uri _buildRealtimeUri(String token, [String? overrideRealtimeUrl]) {
    final graphqlHost = Uri.parse(graphqlUrl).host;
    final header = _base64UrlJson({
      'host': graphqlHost,
      'Authorization': token,
    });
    final payload = _base64UrlJson(<String, dynamic>{});
    return Uri.parse(overrideRealtimeUrl ?? realtimeUrl).replace(
      queryParameters: {
        'header': header,
        'payload': payload,
      },
    );
  }

  Map<String, dynamic> _buildSubscriptionStartMessage({
    required String token,
    required String targetUserId,
  }) {
    final graphqlHost = Uri.parse(graphqlUrl).host;
    return {
      'id': 'friend-request-$targetUserId',
      'type': 'start',
      'payload': {
        'data': jsonEncode({
          'query': '''
subscription OnFriendRequestReceived(\$targetUserId: ID!) {
  onFriendRequestReceived(targetUserId: \$targetUserId) {
    eventId
    targetUserId
    requesterId
    requesterName
    requesterUsername
    requesterAvatarUrl
    createdAt
  }
}
''',
          'variables': {'targetUserId': targetUserId},
        }),
        'extensions': {
          'authorization': {
            'host': graphqlHost,
            'Authorization': token,
          },
        },
      },
    };
  }

  void _handleSocketMessage(
    dynamic message,
    StreamController<FriendRequestRealtimeEvent> controller,
  ) {
    final decoded = jsonDecode(message as String) as Map<String, dynamic>;
    final type = decoded['type'] as String?;
    if (type == 'data') {
      final payload = decoded['payload'] as Map<String, dynamic>?;
      final data = payload?['data'] as Map<String, dynamic>?;
      final event = data?['onFriendRequestReceived'] as Map<String, dynamic>?;
      if (event != null) {
        controller.add(FriendRequestRealtimeEvent.fromGraphqlData(event));
      }
    } else if (type == 'error') {
      controller.addError((decoded['payload'] ?? decoded) as Object);
    }
  }

  String _base64UrlJson(Map<String, dynamic> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }
}
