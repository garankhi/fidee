import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class Comment {
  final String id;
  final String content;
  final String userId;
  final String userName;
  final String? userUsername;
  final String? userAvatar;
  final String? parentId;
  final int replyCount;
  final DateTime createdAt;
  final String? replyToUserId;
  final String? replyToUserName;
  final List<Comment> replies;

  const Comment({
    required this.id,
    required this.content,
    required this.userId,
    required this.userName,
    this.userUsername,
    this.userAvatar,
    this.parentId,
    this.replyCount = 0,
    required this.createdAt,
    this.replyToUserId,
    this.replyToUserName,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final repliesJson = json['replies'] as List<dynamic>? ?? [];
    return Comment(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      userId: (json['userId'] ?? json['user_id'])?.toString() ?? '',
      userName: (json['userName'] ?? json['user_name'])?.toString() ?? '',
      userUsername: (json['userUsername'] ?? json['user_username'])?.toString(),
      userAvatar: (json['userAvatar'] ?? json['user_avatar'])?.toString(),
      parentId: (json['parentId'] ?? json['parent_id'])?.toString(),
      replyCount:
          ((json['replyCount'] ?? json['reply_count']) as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
      replyToUserId: (json['replyToUserId'] ?? json['reply_to_user_id'])
          ?.toString(),
      replyToUserName: (json['replyToUserName'] ?? json['reply_to_user_name'])
          ?.toString(),
      replies: repliesJson
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Comment copyWith({List<Comment>? replies, int? replyCount}) {
    return Comment(
      id: id,
      content: content,
      userId: userId,
      userName: userName,
      userUsername: userUsername,
      userAvatar: userAvatar,
      parentId: parentId,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt,
      replyToUserId: replyToUserId,
      replyToUserName: replyToUserName,
      replies: replies ?? this.replies,
    );
  }
}

class CommentPage {
  final List<Comment> comments;
  final String? nextCursor;
  final bool hasMore;

  const CommentPage({
    required this.comments,
    this.nextCursor,
    this.hasMore = false,
  });

  factory CommentPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    final pagination = json['pagination'] as Map<String, dynamic>? ?? const {};
    return CommentPage(
      comments: data
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: (pagination['nextCursor'] ?? pagination['next_cursor'])
          ?.toString(),
      hasMore: (pagination['hasMore'] ?? pagination['has_more']) == true,
    );
  }
}

class CommentException implements Exception {
  final String message;
  const CommentException(this.message);

  @override
  String toString() => message;
}

class CommentService {
  final AuthService _authService;
  final http.Client _client;

  CommentService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const CommentException('Phiên đăng nhập đã hết hạn');
    }
    return {'Authorization': token, 'Content-Type': 'application/json'};
  }

  Future<CommentPage> getComments({
    required String targetType,
    required String targetId,
    String? cursor,
    int limit = 20,
  }) async {
    final headers = await _headers();

    final queryParams = <String, String>{
      'targetType': targetType,
      'targetId': targetId,
      'limit': limit.toString(),
    };
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final uri = Uri.parse(
      '${Config.apiBaseUrl}/comments',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode != 200) {
        debugPrint(
          'Get comments failed: ${response.statusCode} ${response.body}',
        );
        throw CommentException(
          'Không tải được bình luận: HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return CommentPage.fromJson(decoded);
    } catch (error) {
      if (error is CommentException) rethrow;
      debugPrint('Get comments error: $error');
      throw const CommentException(
        'Không tải được bình luận, vui lòng thử lại',
      );
    }
  }

  Future<CommentPage> getReplies({
    required String commentId,
    String? cursor,
    int limit = 20,
  }) async {
    final headers = await _headers();

    final queryParams = <String, String>{'limit': limit.toString()};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }

    final uri = Uri.parse(
      '${Config.apiBaseUrl}/comments/$commentId/replies',
    ).replace(queryParameters: queryParams);

    try {
      final response = await _client.get(uri, headers: headers);

      if (response.statusCode != 200) {
        debugPrint(
          'Get replies failed: ${response.statusCode} ${response.body}',
        );
        throw CommentException(
          'Không tải được phản hồi: HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return CommentPage.fromJson(decoded);
    } catch (error) {
      if (error is CommentException) rethrow;
      debugPrint('Get replies error: $error');
      throw const CommentException('Không tải được phản hồi, vui lòng thử lại');
    }
  }

  Future<Comment?> createComment({
    required String targetType,
    required String targetId,
    required String content,
    String? parentId,
  }) async {
    final headers = await _headers();

    final payload = <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'content': content,
    };
    if (parentId != null && parentId.isNotEmpty) {
      payload['parentId'] = parentId;
    }

    try {
      final response = await _client.post(
        Uri.parse('${Config.apiBaseUrl}/comments'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        debugPrint(
          'Create comment failed: ${response.statusCode} ${response.body}',
        );
        throw CommentException(
          'Không gửi được bình luận: HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : decoded;
      return Comment.fromJson(data);
    } catch (error) {
      if (error is CommentException) rethrow;
      debugPrint('Create comment error: $error');
      throw const CommentException(
        'Không gửi được bình luận, vui lòng thử lại',
      );
    }
  }

  Future<bool> deleteComment(String commentId) async {
    final headers = await _headers();

    try {
      final response = await _client.delete(
        Uri.parse('${Config.apiBaseUrl}/comments/$commentId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint(
          'Delete comment failed: ${response.statusCode} ${response.body}',
        );
        return false;
      }

      return true;
    } catch (error) {
      debugPrint('Delete comment error: $error');
      return false;
    }
  }
}
