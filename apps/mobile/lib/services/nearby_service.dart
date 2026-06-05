import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/nearby_place.dart';
import 'auth_service.dart';

/// Service that provides nearby places data from the backend.
class NearbyService {
  final AuthService _authService;

  const NearbyService(this._authService);

  /// Fetch nearby places based on coordinates.
  Future<NearbyResponse> fetchNearby({
    required double lat,
    required double lng,
    int radius = 50,
    required String mediaId,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return NearbyResponse.fromJson(_mockFallback(lat, lng));
    }

    try {
      final uri = Uri.parse(
        '${Config.apiBaseUrl}/places/nearby?lat=$lat&lng=$lng&radius=$radius&media_id=$mediaId',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': token},
      );

      if (response.statusCode != 200) {
        return NearbyResponse.fromJson(_mockFallback(lat, lng));
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return NearbyResponse.fromJson(decoded);
    } catch (error) {
      debugPrint('Error fetching nearby places: $error');
      return NearbyResponse.fromJson(_mockFallback(lat, lng));
    }
  }

  static Map<String, dynamic> _mockFallback(double lat, double lng) {
    return {
      'status': 'success',
      'metadata': {
        'source': 'local_fallback',
        'has_goong_fallback': false,
        'total_results': 1,
      },
      'data': [
        {
          'id': 'custom_fallback',
          'place_id': null,
          'source': 'custom',
          'display_name': 'Tạo địa điểm mới tại đây',
          'address': 'Gần vị trí hiện tại',
          'category': 'custom',
          'distance_meters': 0,
          'confidence': 'low',
          'coordinates': {'lat': lat, 'lng': lng},
          'actions': {'primary': 'create_custom_place'},
        },
      ],
    };
  }
}
