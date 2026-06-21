import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int maxVideoUploadBytes = 20 * 1024 * 1024;

String detectUploadContentType(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    _ => 'image/jpeg',
  };
}

bool isVideoUploadTooLarge({
  required String contentType,
  required int byteLength,
}) {
  return contentType.startsWith('video/') && byteLength > maxVideoUploadBytes;
}

class PendingUpload {
  final String id;
  final String imagePath;
  final double longitude;
  final double latitude;
  final String source; // 'IN_APP_CAMERA' or 'EXIF_GALLERY'
  final DateTime failedAt;

  const PendingUpload({
    required this.id,
    required this.imagePath,
    required this.longitude,
    required this.latitude,
    required this.source,
    required this.failedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'longitude': longitude,
    'latitude': latitude,
    'source': source,
    'failedAt': failedAt.toIso8601String(),
  };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    source: json['source'] as String,
    failedAt: DateTime.parse(json['failedAt'] as String),
  );
}

class _PresignedPost {
  final String mediaId;
  final String url;
  final Map<String, String> fields;

  const _PresignedPost({
    required this.mediaId,
    required this.url,
    required this.fields,
  });

  factory _PresignedPost.fromJson(Map<String, dynamic> json) {
    final upload = json['upload'] as Map<String, dynamic>;

    return _PresignedPost(
      mediaId: json['mediaId'] as String,
      url: upload['url'] as String,
      fields: Map<String, String>.from(upload['fields'] as Map),
    );
  }
}

class UploadService {
  static const _pendingKey = 'pending_uploads';
  final AuthService _authService;
  final Dio _dio;

  UploadService({required AuthService authService})
    : _authService = authService,
      _dio = Dio(
        BaseOptions(
          baseUrl: Config.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  Future<String> upload({
    required String imagePath,
    required double longitude,
    required double latitude,
    required String source,
    String? contentTypeOverride,
    int? durationMs,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(imagePath);

    if (!file.existsSync()) {
      throw UploadException('File ảnh không tồn tại: $imagePath');
    }

    final stat = await file.stat();
    final contentType =
        contentTypeOverride ?? detectUploadContentType(imagePath);
    if (isVideoUploadTooLarge(
      contentType: contentType,
      byteLength: stat.size,
    )) {
      throw UploadException('Video phải nhỏ hơn 20MB');
    }

    final presigned = await _getPresignedUrl(
      source: source,
      contentType: contentType,
      contentLength: stat.size,
      latitude: latitude,
      longitude: longitude,
      durationMs: durationMs,
    );

    await _uploadToS3(presigned, file, onProgress: onProgress);

    return presigned.mediaId;
  }

  Future<_PresignedPost> _getPresignedUrl({
    required String source,
    required String contentType,
    required int contentLength,
    required double latitude,
    required double longitude,
    int? durationMs,
  }) async {
    final token = await _authService.getToken();

    if (token == null) {
      debugPrint('DEBUG [UploadService]: auth token is null');
      throw UploadException('Phiên đăng nhập đã hết hạn');
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/media/uploads',
        data: {
          'source': source,
          'contentType': contentType,
          'contentLength': contentLength,
          'durationMs': ?durationMs,
          'gpsProof': {
            'latitude': latitude,
            'longitude': longitude,
            'capturedAt': DateTime.now().toIso8601String(),
          },
        },
        options: Options(headers: {'Authorization': token}),
      );

      return _PresignedPost.fromJson(response.data!);
    } on DioException catch (e) {
      _throwFromDioError(e);
    }
  }

  Future<void> _uploadToS3(
    _PresignedPost presigned,
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final formData = FormData();

    for (final entry in presigned.fields.entries) {
      formData.fields.add(MapEntry(entry.key, entry.value));
    }

    formData.files.add(
      MapEntry(
        'file',
        await MultipartFile.fromFile(
          file.path,
          contentType: DioMediaType.parse(
            presigned.fields['Content-Type'] ?? 'image/jpeg',
          ),
        ),
      ),
    );
    try {
      final uploadDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      final response = await uploadDio.post<void>(
        presigned.url,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode != 204) {
        throw UploadException(
          'Upload thất bại với mã HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      _throwFromDioError(e);
    }
  }

  Never _throwFromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw UploadException('Kết nối quá chậm, vui lòng thử lại');

      case DioExceptionType.connectionError:
        throw UploadException('Không có kết nối mạng');

      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        final responseData = e.response?.data;
        debugPrint(
          'DEBUG [UploadService]: HTTP Bad Response Status: $status, Data: $responseData',
        );
        if (status == 401) throw UploadException('Phiên đăng nhập đã hết hạn');
        if (status == 403) {
          final errorData = e.response?.data?.toString() ?? 'Lỗi 403 ẩn';
          throw UploadException('Tài khoản không có quyền upload: $errorData');
        }
        if (status == 400) throw UploadException('Dữ liệu không hợp lệ');
        throw UploadException('Lỗi server: HTTP $status');

      default:
        throw UploadException('Upload thất bại, vui lòng thử lại');
    }
  }

  Future<void> savePending(PendingUpload upload) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingKey) ?? [];
    existing.add(jsonEncode(upload.toJson()));
    await prefs.setStringList(_pendingKey, existing);
  }

  /// Đọc toàn bộ danh sách upload đang chờ retry.
  Future<List<PendingUpload>> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pendingKey) ?? [];

    // Dùng whereType để lọc bỏ item parse lỗi (file JSON hỏng)
    return raw
        .map((s) {
          try {
            return PendingUpload.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null; // item hỏng → bỏ qua
          }
        })
        .whereType<PendingUpload>()
        .toList();
  }

  /// Xóa một upload khỏi hàng đợi sau khi retry thành công.
  Future<void> removePending(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_pendingKey) ?? [];

    existing.removeWhere((s) {
      try {
        final map = jsonDecode(s) as Map<String, dynamic>;
        return map['id'] == id;
      } catch (_) {
        return true; // item hỏng → cũng xóa luôn
      }
    });

    await prefs.setStringList(_pendingKey, existing);
  }
}

class UploadException implements Exception {
  final String message;

  UploadException(this.message);

  @override
  String toString() => message;
}
