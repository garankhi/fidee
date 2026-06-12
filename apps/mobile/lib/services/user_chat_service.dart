import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config.dart';
import 'auth_service.dart';

class ChatUserSummary {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;
  final String presenceStatus;

  const ChatUserSummary({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.presenceStatus = 'UNKNOWN',
  });

  factory ChatUserSummary.fromJson(Map<String, dynamic> json) {
    return ChatUserSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['username'] as String? ?? 'Friend',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      presenceStatus: json['presenceStatus'] as String? ?? 'UNKNOWN',
    );
  }
}

class UserChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String clientMessageId;
  final String body;
  final String status;
  final DateTime createdAt;
  final bool isPending;

  const UserChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    required this.status,
    required this.createdAt,
    this.isPending = false,
  });

  factory UserChatMessage.fromJson(Map<String, dynamic> json) {
    return UserChatMessage(
      id: json['id'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      clientMessageId: json['clientMessageId'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'SENT',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  UserChatMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? clientMessageId,
    String? body,
    String? status,
    DateTime? createdAt,
    bool? isPending,
  }) {
    return UserChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      body: body ?? this.body,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      isPending: isPending ?? this.isPending,
    );
  }
}

class UserChatConversation {
  final String id;
  final ChatUserSummary otherUser;
  final UserChatMessage? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  const UserChatConversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  factory UserChatConversation.fromJson(Map<String, dynamic> json) {
    final lastMessageJson = json['lastMessage'] as Map<String, dynamic>?;
    return UserChatConversation(
      id: json['id'] as String? ?? '',
      otherUser: ChatUserSummary.fromJson(
        (json['otherUser'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      lastMessage: lastMessageJson == null
          ? null
          : UserChatMessage.fromJson({
              'id': lastMessageJson['id'],
              'conversationId': json['id'],
              'senderId': lastMessageJson['senderId'],
              'clientMessageId': '',
              'body': lastMessageJson['body'],
              'status': 'SENT',
              'createdAt': lastMessageJson['createdAt'],
            }),
      unreadCount: int.tryParse(json['unreadCount']?.toString() ?? '0') ?? 0,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  UserChatConversation copyWith({
    ChatUserSummary? otherUser,
    UserChatMessage? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
  }) {
    return UserChatConversation(
      id: id,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class UserChatService {
  final AuthService _authService;
  final http.Client _client;

  UserChatService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  String createClientMessageId() => const Uuid().v4();

  Future<String?> createDirectConversation(String targetUserId) async {
    final response = await _post('/conversations/direct', {
      'targetUserId': targetUserId,
    });
    final conversation = response?['conversation'] as Map<String, dynamic>?;
    return conversation?['id'] as String?;
  }

  Future<List<UserChatConversation>> fetchConversations() async {
    final response = await _get('/conversations');
    final items =
        (response?['conversations'] as List<dynamic>?) ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(UserChatConversation.fromJson)
        .toList(growable: false);
  }

  Future<List<UserChatMessage>> fetchMessages(
    String conversationId, {
    DateTime? before,
  }) async {
    final query = before == null ? '' : '?before=${before.toIso8601String()}';
    final response = await _get(
      '/conversations/$conversationId/messages$query',
    );
    final items =
        (response?['messages'] as List<dynamic>?) ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(UserChatMessage.fromJson)
        .toList(growable: false);
  }

  Future<UserChatMessage?> sendMessage({
    required String conversationId,
    required String clientMessageId,
    required String body,
  }) async {
    final response = await _post('/conversations/$conversationId/messages', {
      'clientMessageId': clientMessageId,
      'body': body,
    });
    final message = response?['message'] as Map<String, dynamic>?;
    return message == null ? null : UserChatMessage.fromJson(message);
  }

  Future<void> markRead({
    required String conversationId,
    required String messageId,
  }) async {
    await _post('/conversations/$conversationId/read', {
      'messageId': messageId,
    });
  }

  Future<void> markDelivered({
    required String conversationId,
    required String messageId,
  }) async {
    await _post('/conversations/$conversationId/delivered', {
      'messageId': messageId,
    });
  }

  Future<void> sendTyping({
    required String conversationId,
    required bool isTyping,
  }) async {
    await _post('/conversations/$conversationId/typing', {
      'isTyping': isTyping,
    });
  }

  Future<void> heartbeat({String deviceId = 'mobile'}) async {
    await _post('/presence/heartbeat', {'deviceId': deviceId});
  }

  Future<Map<String, dynamic>?> _get(String path) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _client.get(
        Uri.parse('${Config.apiBaseUrl}$path'),
        headers: {'Authorization': token},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('UserChatService GET $path error: $error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _client.post(
        Uri.parse('${Config.apiBaseUrl}$path'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      debugPrint('UserChatService POST $path error: $error');
      return null;
    }
  }
}
