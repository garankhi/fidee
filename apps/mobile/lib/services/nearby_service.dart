import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/nearby_place.dart';
import 'auth_service.dart';

class NearbyException implements Exception {
  final String message;

  const NearbyException(this.message);

  @override
  String toString() => message;
}

/// Service that provides nearby places data from the backend.
class NearbyService {
  final AuthService _authService;
  final http.Client _client;

  NearbyService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  /// Fetch nearby places based on coordinates.
  Future<NearbyResponse> fetchNearby({
    required double lat,
    required double lng,
    int radius = 50,
    String? mediaId,
    String? query,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const NearbyException('Missing auth token for nearby places');
    }

    final uri = Uri.parse('${Config.apiBaseUrl}/places/nearby').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radius.toString(),
        if (mediaId != null && mediaId.isNotEmpty) 'media_id': mediaId,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    try {
      final response = await _client.get(
        uri,
        headers: {'Authorization': token},
      );

      if (response.statusCode != 200) {
        final body = response.body.length > 240
            ? '${response.body.substring(0, 240)}…'
            : response.body;
        throw NearbyException(
          'Nearby places failed ${response.statusCode}: $body',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return NearbyResponse.fromJson(decoded);
    } catch (error) {
      debugPrint('Error fetching nearby places $uri: $error');
      if (error is NearbyException) rethrow;
      throw NearbyException('Nearby places request failed: $error');
    }
  }
}
