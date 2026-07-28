import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

/// Response from POST /place-candidates
class PlaceCandidateResponse {
  final String status;
  final PlaceCandidateData? data;
  final PlaceCandidateError? error;
  final List<ConflictCandidate>? candidates;

  const PlaceCandidateResponse({
    required this.status,
    this.data,
    this.error,
    this.candidates,
  });

  bool get isCreated => status == 'created';
  bool get isConflict => status == 'conflict';
  bool get isQuotaExceeded => error?.code == 'QUOTA_EXCEEDED';
}

class PlaceCandidateServiceException implements Exception {
  final String message;
  const PlaceCandidateServiceException(this.message);

  @override
  String toString() => message;
}

void _debugPlaceCandidate(String message) {
  if (kDebugMode) debugPrint('[PlaceCandidateService] $message');
}

String _truncateForDebug(String value, [int maxLength = 1200]) {
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}...';
}

String _requiredString(
  Map<String, dynamic> json,
  String snakeKey,
  String camelKey,
) {
  final value = json[snakeKey] ?? json[camelKey];
  if (value is String) return value;
  throw FormatException('Missing string field $snakeKey/$camelKey');
}

int _requiredInt(Map<String, dynamic> json, String snakeKey, String camelKey) {
  final value = json[snakeKey] ?? json[camelKey];
  if (value is num) return value.toInt();
  throw FormatException('Missing numeric field $snakeKey/$camelKey');
}

class PlaceCandidateData {
  final String candidateId;
  final String name;
  final String category;
  final String status;
  final String visibility;
  final String createdAt;

  const PlaceCandidateData({
    required this.candidateId,
    required this.name,
    required this.category,
    required this.status,
    required this.visibility,
    required this.createdAt,
  });

  factory PlaceCandidateData.fromJson(Map<String, dynamic> json) {
    return PlaceCandidateData(
      candidateId: json['candidate_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      visibility: json['visibility'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}

class PlaceCandidateError {
  final String code;
  final String message;
  final int? dailyLimit;
  final int? used;

  const PlaceCandidateError({
    required this.code,
    required this.message,
    this.dailyLimit,
    this.used,
  });

  factory PlaceCandidateError.fromJson(Map<String, dynamic> json) {
    return PlaceCandidateError(
      code: json['code'] as String,
      message: json['message'] as String,
      dailyLimit: (json['daily_limit'] as num?)?.toInt(),
      used: (json['used'] as num?)?.toInt(),
    );
  }
}

class ConflictCandidate {
  final String candidateId;
  final String name;
  final int distanceMeters;

  const ConflictCandidate({
    required this.candidateId,
    required this.name,
    required this.distanceMeters,
  });

  factory ConflictCandidate.fromJson(Map<String, dynamic> json) {
    return ConflictCandidate(
      candidateId: _requiredString(json, 'candidate_id', 'candidateId'),
      name: json['name'] as String,
      distanceMeters: _requiredInt(json, 'distance_meters', 'distanceMeters'),
    );
  }
}

class PlaceCandidateService {
  final AuthService _authService;
  final http.Client _client;

  PlaceCandidateService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<PlaceCandidateResponse> createCandidate({
    required String name,
    required String category,
    required String mediaId,
    required double lat,
    required double lng,
    bool force = false,
    String? address,
    String? openTime,
    String? closeTime,
    int? priceMin,
    int? priceMax,
    String? phoneNumber,
    String? description,
    String visibility = 'FRIENDS',
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const PlaceCandidateResponse(
        status: 'error',
        error: PlaceCandidateError(
          code: 'UNAUTHORIZED',
          message: 'Bạn cần đăng nhập lại',
        ),
      );
    }

    final payload = {
      'name': name,
      'category': category,
      'coordinates': {'lat': lat, 'lng': lng},
      'force': force,
      'address': ?address,
      'openTime': ?openTime,
      'closeTime': ?closeTime,
      'priceMin': ?priceMin,
      'priceMax': ?priceMax,
      'phoneNumber': ?phoneNumber,
      'description': ?description,
      'visibility': visibility,
    };
    payload['mediaId'] = mediaId;

    _debugPlaceCandidate('createCandidate request ${jsonEncode(payload)}');

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/place-candidates'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    _debugPlaceCandidate(
      'createCandidate response ${response.statusCode}: '
      '${_truncateForDebug(response.body)}',
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return PlaceCandidateResponse(
        status: decoded['status'] as String? ?? 'created',
        data: PlaceCandidateData.fromJson(
          decoded['data'] as Map<String, dynamic>,
        ),
      );
    }

    if (response.statusCode == 409) {
      return PlaceCandidateResponse(
        status: decoded['status'] as String? ?? 'conflict',
        error: PlaceCandidateError.fromJson(
          decoded['error'] as Map<String, dynamic>,
        ),
        candidates: (decoded['candidates'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ConflictCandidate.fromJson)
            .toList(growable: false),
      );
    }

    return PlaceCandidateResponse(
      status: decoded['status'] as String? ?? 'error',
      error: PlaceCandidateError.fromJson(
        decoded['error'] as Map<String, dynamic>,
      ),
    );
  }

  Future<Map<String, dynamic>> updateCandidate({
    required String candidateId,
    String? address,
    String? openTime,
    String? closeTime,
    int? priceMin,
    int? priceMax,
    String? phoneNumber,
    String? description,
    String? visibility,
    String? mediaId,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const PlaceCandidateServiceException('Bạn cần đăng nhập lại');
    }

    final payload = {
      'address': ?address,
      'openTime': ?openTime,
      'closeTime': ?closeTime,
      'priceMin': ?priceMin,
      'priceMax': ?priceMax,
      'phoneNumber': ?phoneNumber,
      'description': ?description,
      'visibility': ?visibility,
      'mediaId': ?mediaId,
    };

    final response = await _client.patch(
      Uri.parse('${Config.apiBaseUrl}/place-candidates/$candidateId'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic>
          ? error['message'] as String? ?? 'Không cập nhật được địa điểm'
          : 'Không cập nhật được địa điểm';
      throw PlaceCandidateServiceException(message);
    }

    return decoded;
  }

  /// Reset mock state (for testing)
  static void resetMock() {
    // no-op after real API wiring
  }
}
