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

class ChatRealtimeMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String clientMessageId;
  final String body;
  final String status;
  final DateTime createdAt;

  const ChatRealtimeMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.status,
    required this.createdAt,
  });

  factory ChatRealtimeMessage.fromGraphqlData(Map<String, dynamic> data) {
    return ChatRealtimeMessage(
      id: data['id'] as String? ?? '',
      conversationId: data['conversationId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      clientMessageId: data['clientMessageId'] as String? ?? '',
      body: data['body'] as String? ?? '',
      status: data['status'] as String? ?? 'SENT',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatRealtimeReceipt {
  final String conversationId;
  final String messageId;
  final String userId;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  const ChatRealtimeReceipt({
    required this.conversationId,
    required this.messageId,
    required this.userId,
    this.deliveredAt,
    this.readAt,
  });

  factory ChatRealtimeReceipt.fromGraphqlData(Map<String, dynamic> data) {
    return ChatRealtimeReceipt(
      conversationId: data['conversationId'] as String? ?? '',
      messageId: data['messageId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      deliveredAt: DateTime.tryParse(data['deliveredAt'] as String? ?? ''),
      readAt: DateTime.tryParse(data['readAt'] as String? ?? ''),
    );
  }
}

class ChatRealtimeTyping {
  final String conversationId;
  final String userId;
  final bool isTyping;

  const ChatRealtimeTyping({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  factory ChatRealtimeTyping.fromGraphqlData(Map<String, dynamic> data) {
    return ChatRealtimeTyping(
      conversationId: data['conversationId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      isTyping: data['isTyping'] as bool? ?? false,
    );
  }
}

class ChatRealtimePresence {
  final String userId;
  final String status;
  final DateTime lastSeenAt;

  const ChatRealtimePresence({
    required this.userId,
    required this.status,
    required this.lastSeenAt,
  });

  factory ChatRealtimePresence.fromGraphqlData(Map<String, dynamic> data) {
    return ChatRealtimePresence(
      userId: data['userId'] as String? ?? '',
      status: data['status'] as String? ?? 'UNKNOWN',
      lastSeenAt:
          DateTime.tryParse(data['lastSeenAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class ChatRealtimeEvent {
  final String eventId;
  final String type;
  final String targetUserId;
  final String? conversationId;
  final ChatRealtimeMessage? message;
  final ChatRealtimeReceipt? receipt;
  final ChatRealtimeTyping? typing;
  final ChatRealtimePresence? presence;
  final DateTime createdAt;

  const ChatRealtimeEvent({
    required this.eventId,
    required this.type,
    required this.targetUserId,
    this.conversationId,
    this.message,
    this.receipt,
    this.typing,
    this.presence,
    required this.createdAt,
  });

  factory ChatRealtimeEvent.fromGraphqlData(Map<String, dynamic> data) {
    final message = data['message'] as Map<String, dynamic>?;
    final receipt = data['receipt'] as Map<String, dynamic>?;
    final typing = data['typing'] as Map<String, dynamic>?;
    final presence = data['presence'] as Map<String, dynamic>?;
    return ChatRealtimeEvent(
      eventId: data['eventId'] as String? ?? '',
      type: data['type'] as String? ?? '',
      targetUserId: data['targetUserId'] as String? ?? '',
      conversationId: data['conversationId'] as String?,
      message: message == null
          ? null
          : ChatRealtimeMessage.fromGraphqlData(message),
      receipt: receipt == null
          ? null
          : ChatRealtimeReceipt.fromGraphqlData(receipt),
      typing: typing == null
          ? null
          : ChatRealtimeTyping.fromGraphqlData(typing),
      presence: presence == null
          ? null
          : ChatRealtimePresence.fromGraphqlData(presence),
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

  final List<WebSocketChannel> _channels = <WebSocketChannel>[];
  final List<StreamSubscription<dynamic>> _socketSubscriptions =
      <StreamSubscription<dynamic>>[];

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
    unawaited(
      _connectSubscription<FriendRealtimeEvent>(
        targetUserId: targetUserId,
        controller: controller,
        subscriptionId: 'friend-realtime-$targetUserId',
        query: _friendRealtimeQuery,
        eventFieldName: 'onFriendRealtimeEvent',
        parseEvent: FriendRealtimeEvent.fromGraphqlData,
      ),
    );
    return controller.stream;
  }

  Stream<ChatRealtimeEvent> subscribeToChatEvents({
    required String targetUserId,
  }) {
    final controller = StreamController<ChatRealtimeEvent>();
    unawaited(
      _connectSubscription<ChatRealtimeEvent>(
        targetUserId: targetUserId,
        controller: controller,
        subscriptionId: 'chat-realtime-$targetUserId',
        query: _chatRealtimeQuery,
        eventFieldName: 'onChatRealtimeEvent',
        parseEvent: ChatRealtimeEvent.fromGraphqlData,
      ),
    );
    return controller.stream;
  }

  Future<void> disconnect() async {
    for (final subscription in _socketSubscriptions) {
      await subscription.cancel();
    }
    _socketSubscriptions.clear();
    for (final channel in _channels) {
      await channel.sink.close();
    }
    _channels.clear();
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
      subscriptionId: 'friend-realtime-$targetUserId',
      query: _friendRealtimeQuery,
    );
  }

  @visibleForTesting
  Map<String, dynamic> buildChatSubscriptionStartMessageForTesting({
    required String token,
    required String targetUserId,
  }) {
    return _buildSubscriptionStartMessage(
      token: token,
      targetUserId: targetUserId,
      subscriptionId: 'chat-realtime-$targetUserId',
      query: _chatRealtimeQuery,
    );
  }

  Future<void> _connectSubscription<T>({
    required String targetUserId,
    required StreamController<T> controller,
    required String subscriptionId,
    required String query,
    required String eventFieldName,
    required T Function(Map<String, dynamic> data) parseEvent,
  }) async {
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
      _channels.add(channel);
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
              subscriptionId: subscriptionId,
              query: query,
            ),
          ),
        );
      }

      final subscription = channel.stream.listen(
        (message) => _handleSocketMessage(
          message,
          controller,
          eventFieldName: eventFieldName,
          parseEvent: parseEvent,
          onConnectionAck: startSubscription,
        ),
        onError: controller.addError,
        onDone: controller.close,
      );
      _socketSubscriptions.add(subscription);
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
    required String subscriptionId,
    required String query,
  }) {
    final graphqlHost = Uri.parse(graphqlUrl).host;
    return {
      'id': subscriptionId,
      'type': 'start',
      'payload': {
        'data': jsonEncode({
          'query': query,
          'variables': {'targetUserId': targetUserId},
        }),
        'extensions': {
          'authorization': {'host': graphqlHost, 'Authorization': token},
        },
      },
    };
  }

  static const String _friendRealtimeQuery = r'''
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
''';

  static const String _chatRealtimeQuery = r'''
subscription OnChatRealtimeEvent($targetUserId: ID!) {
  onChatRealtimeEvent(targetUserId: $targetUserId) {
    eventId
    type
    targetUserId
    conversationId
    message {
      id
      conversationId
      senderId
      clientMessageId
      body
      status
      createdAt
    }
    receipt {
      conversationId
      messageId
      userId
      deliveredAt
      readAt
    }
    typing {
      conversationId
      userId
      isTyping
    }
    presence {
      userId
      status
      lastSeenAt
    }
    createdAt
  }
}
''';

  void _handleSocketMessage<T>(
    dynamic message,
    StreamController<T> controller, {
    required String eventFieldName,
    required T Function(Map<String, dynamic> data) parseEvent,
    required VoidCallback onConnectionAck,
  }) {
    final decoded = jsonDecode(message as String) as Map<String, dynamic>;
    final type = decoded['type'] as String?;
    if (type == 'connection_ack') {
      onConnectionAck();
    } else if (type == 'data') {
      final payload = decoded['payload'] as Map<String, dynamic>?;
      final data = payload?['data'] as Map<String, dynamic>?;
      final event = data?[eventFieldName] as Map<String, dynamic>?;
      if (event != null) {
        controller.add(parseEvent(event));
      }
    } else if (type == 'error' || type == 'connection_error') {
      controller.addError((decoded['payload'] ?? decoded) as Object);
    }
  }

  String _base64Json(Map<String, dynamic> value) {
    return base64.encode(utf8.encode(jsonEncode(value)));
  }
}
