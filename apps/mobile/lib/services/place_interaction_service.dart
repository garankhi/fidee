import 'package:dio/dio.dart';

import '../config.dart';
import 'auth_service.dart';

class PlaceInteractionService {
  final AuthService _authService;
  final Dio _dio;

  PlaceInteractionService(this._authService)
    : _dio = Dio(BaseOptions(baseUrl: Config.apiBaseUrl));

  Future<void> createCheckin({
    required String targetId,
    required bool isCandidate,
    required String mediaId,
    required double latitude,
    required double longitude,
    String? caption,
  }) async {
    final token = await _requireToken();
    await _dio.post<void>(
      '/check-ins',
      data: {
        if (isCandidate) 'candidate_id': targetId else 'place_id': targetId,
        'media_id': mediaId,
        'gps_lat': latitude,
        'gps_lng': longitude,
        'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
        'visibility': 'FRIENDS',
      },
      options: Options(headers: {'Authorization': token}),
    );
  }

  Future<void> createReview({
    required String targetId,
    required bool isCandidate,
    required int rating,
    String? content,
  }) async {
    final token = await _requireToken();
    await _dio.post<void>(
      '/reviews',
      data: {
        if (isCandidate) 'candidateId': targetId else 'placeId': targetId,
        'rating': rating,
        'content': content?.trim(),
        'visibility': 'FRIENDS',
      },
      options: Options(headers: {'Authorization': token}),
    );
  }

  Future<String> _requireToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('Phiên đăng nhập đã hết hạn.');
    }
    return token;
  }
}
