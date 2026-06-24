import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/journey_entry.dart';
import 'auth_service.dart';

class JourneyException implements Exception {
  final String message;

  const JourneyException(this.message);

  @override
  String toString() => message;
}

class JourneyService {
  final AuthService _authService;
  final http.Client _client;

  JourneyService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<JourneyPage> fetchCheckins({int limit = 20, String? cursor}) {
    return _fetch(
      type: JourneyEntryType.checkin,
      path: '/journey/checkins',
      limit: limit,
      cursor: cursor,
    );
  }

  Future<JourneyPage> fetchReviews({int limit = 20, String? cursor}) {
    return _fetch(
      type: JourneyEntryType.review,
      path: '/journey/reviews',
      limit: limit,
      cursor: cursor,
    );
  }

  Future<JourneyPage> _fetch({
    required JourneyEntryType type,
    required String path,
    required int limit,
    String? cursor,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const JourneyException('Your session has expired.');
    }

    final uri = Uri.parse('${Config.apiBaseUrl}$path').replace(
      queryParameters: <String, String>{
        'limit': limit.toString(),
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: <String, String>{'Authorization': token},
      );
      if (response.statusCode != 200) {
        throw const JourneyException('Could not load your journey.');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final pagination =
          decoded['pagination'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      final entries = ((decoded['data'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map((item) => JourneyEntry.fromJson(item, type: type))
          .toList(growable: false);

      return JourneyPage(
        entries: entries,
        nextCursor: pagination['nextCursor'] as String?,
        hasMore: pagination['hasMore'] as bool? ?? false,
      );
    } on JourneyException {
      rethrow;
    } catch (_) {
      throw const JourneyException('Could not load your journey.');
    }
  }
}
