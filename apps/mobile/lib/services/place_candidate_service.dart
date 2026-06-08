import 'dart:convert';

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
      candidateId: json['candidate_id'] as String,
      name: json['name'] as String,
      distanceMeters: (json['distance_meters'] as num).toInt(),
    );
  }
}

class PlaceCandidateService {
  final AuthService _authService;

  const PlaceCandidateService(this._authService);

  Future<PlaceCandidateResponse> createCandidate({
    required String name,
    required String category,
    String? mediaId,
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
    };
    if (mediaId != null) {
      payload['mediaId'] = mediaId;
    }

    final response = await http.post(
      Uri.parse('${Config.apiBaseUrl}/place-candidates'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201) {
      return PlaceCandidateResponse(
        status: decoded['status'] as String? ?? 'created',
        data: PlaceCandidateData.fromJson(decoded['data'] as Map<String, dynamic>),
      );
    }

    if (response.statusCode == 409) {
      return PlaceCandidateResponse(
        status: decoded['status'] as String? ?? 'conflict',
        error: PlaceCandidateError.fromJson(decoded['error'] as Map<String, dynamic>),
        candidates: (decoded['candidates'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map(ConflictCandidate.fromJson)
            .toList(growable: false),
      );
    }

    return PlaceCandidateResponse(
      status: decoded['status'] as String? ?? 'error',
      error: PlaceCandidateError.fromJson(decoded['error'] as Map<String, dynamic>),
    );
  }

  /// Reset mock state (for testing)
  static void resetMock() {
    // no-op after real API wiring
  }
}






