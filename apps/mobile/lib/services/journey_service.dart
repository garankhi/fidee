import 'package:http/http.dart' as http;

import '../models/journey_entry.dart';
import 'api_client.dart';
import 'auth_service.dart';

class JourneyException implements Exception {
  final String message;

  const JourneyException(this.message);

  @override
  String toString() => message;
}

class JourneyService {
  final ApiClient _apiClient;

  JourneyService(AuthService authService, {http.Client? client})
    : _apiClient = ApiClient(authService, client: client);

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
    try {
      final decoded = await _apiClient.getJson(
        path,
        queryParameters: <String, String>{
          'limit': limit.toString(),
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        },
      );
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
    } on ApiUnauthorizedException {
      throw const JourneyException('Your session has expired.');
    } on ApiException {
      throw const JourneyException('Could not load your journey.');
    } on JourneyException {
      rethrow;
    } catch (_) {
      throw const JourneyException('Could not load your journey.');
    }
  }
}
