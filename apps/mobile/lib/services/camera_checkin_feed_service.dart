import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/camera_checkin_feed_item.dart';
import 'auth_service.dart';

class CameraCheckinFeedService {
  final AuthService _authService;
  final http.Client _client;

  CameraCheckinFeedService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<CameraCheckinFeedPage> fetchCheckins({
    required CameraFeedAudience audience,
    int limit = 12,
    String? cursor,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) return CameraCheckinFeedPage.empty();

    try {
      final query = <String, String>{
        'filter': audience.type == CameraFeedAudienceType.me
            ? 'me'
            : 'everyone',
        'limit': limit.toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (audience.type == CameraFeedAudienceType.friend &&
            audience.id != null)
          'friendId': audience.id!,
      };
      final uri = Uri.parse(
        '${Config.apiBaseUrl}/feed/checkins',
      ).replace(queryParameters: query);
      final response = await _client.get(
        uri,
        headers: {'Authorization': token},
      );
      if (response.statusCode != 200) return CameraCheckinFeedPage.empty();

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = ((decoded['data'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CameraCheckinFeedItem.fromJson)
          .where((item) => item.imageUrl.isNotEmpty)
          .toList(growable: false);
      final pagination =
          decoded['pagination'] as Map<String, dynamic>? ??
          const <String, dynamic>{};

      return CameraCheckinFeedPage(
        items: items,
        nextCursor: pagination['nextCursor'] as String?,
        hasMore: pagination['hasMore'] as bool? ?? false,
      );
    } catch (error) {
      debugPrint('Error fetching camera check-in feed: $error');
      return CameraCheckinFeedPage.empty();
    }
  }
}
