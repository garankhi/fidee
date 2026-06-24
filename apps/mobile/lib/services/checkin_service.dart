import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/camera_share_audience.dart';
import 'auth_service.dart';

class CheckinResult {
  final String checkinId;
  final String createdAt;

  const CheckinResult({required this.checkinId, required this.createdAt});
}

class CheckinException implements Exception {
  final String message;

  const CheckinException(this.message);

  @override
  String toString() => message;
}

class CheckinService {
  final AuthService _authService;
  final http.Client _client;

  CheckinService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<CheckinResult> createCheckin({
    String? placeId,
    String? candidateId,
    required String mediaId,
    String? mediaType,
    required double gpsLat,
    required double gpsLng,
    double? gpsAccuracy,
    String? caption,
    int? rating,
    required CameraShareAudience audience,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const CheckinException('Phiên đăng nhập đã hết hạn');
    }

    final trimmedCaption = caption?.trim();
    final payload = <String, dynamic>{
      if (placeId != null && placeId.isNotEmpty) 'place_id': placeId,
      if (candidateId != null && candidateId.isNotEmpty)
        'candidate_id': candidateId,
      'media_id': mediaId,
      if (mediaType != null && mediaType.isNotEmpty) 'media_type': mediaType,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'visibility': 'FRIENDS',
      'audience': audience.toApiJson(),
    };
    if (gpsAccuracy != null) {
      payload['gps_accuracy'] = gpsAccuracy;
    }
    if (trimmedCaption != null && trimmedCaption.isNotEmpty) {
      payload['caption'] = trimmedCaption;
    }
    if (rating != null) {
      payload['rating'] = rating;
    }

    try {
      final response = await _client.post(
        Uri.parse('${Config.apiBaseUrl}/check-ins'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 201) {
        throw CheckinException(
          'Không tạo được check-in: HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data =
          decoded['data'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      return CheckinResult(
        checkinId: data['id'] as String? ?? '',
        createdAt: data['created_at'] as String? ?? '',
      );
    } catch (error) {
      if (error is CheckinException) rethrow;
      debugPrint('Create check-in failed: $error');
      throw const CheckinException('Không tạo được check-in, vui lòng thử lại');
    }
  }
}
