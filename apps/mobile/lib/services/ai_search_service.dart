import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

class AiChatHistoryMessage {
  final String role;
  final String text;

  const AiChatHistoryMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

class AiContextPlace {
  final String id;
  final String name;

  const AiContextPlace({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

class AiSearchResult {
  final String answer;
  final String? searchMethod;
  final List<AiPlaceResult> results;

  const AiSearchResult({
    required this.answer,
    this.searchMethod,
    this.results = const <AiPlaceResult>[],
  });

  factory AiSearchResult.fromJson(Map<String, dynamic> json) {
    final resultItems = json['results'] as List<dynamic>? ?? const <dynamic>[];
    return AiSearchResult(
      answer: json['answer'] as String? ?? '',
      searchMethod: json['search_method'] as String?,
      results: resultItems
          .whereType<Map<String, dynamic>>()
          .map(AiPlaceResult.fromJson)
          .where((place) => place.id.isNotEmpty && place.name.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class AiPlaceResult {
  final String id;
  final String name;
  final String? category;
  final String? address;
  final String? description;
  final String? openTime;
  final String? closeTime;
  final int? priceMin;
  final int? priceMax;
  final double? similarityScore;
  final List<String> tags;

  const AiPlaceResult({
    required this.id,
    required this.name,
    this.category,
    this.address,
    this.description,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.similarityScore,
    this.tags = const <String>[],
  });

  factory AiPlaceResult.fromJson(Map<String, dynamic> json) {
    final metadata = _metadataObject(json['metadata']);
    final tags = <String>[
      if (json['category'] != null) _categoryLabel(json['category'].toString()),
      ..._stringList(metadata['vibes']),
      ..._stringList(metadata['services']),
    ];

    return AiPlaceResult(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString(),
      address: json['address']?.toString(),
      description: json['description']?.toString(),
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      priceMin: (json['price_min'] as num?)?.toInt(),
      priceMax: (json['price_max'] as num?)?.toInt(),
      similarityScore: (json['similarity_score'] as num?)?.toDouble(),
      tags: tags.toSet().take(4).toList(growable: false),
    );
  }

  AiContextPlace toContextPlace() => AiContextPlace(id: id, name: name);

  String get priceLabel {
    if (priceMin == null && priceMax == null) return '';
    if (priceMin != null && priceMax != null) {
      return '${_formatPrice(priceMin!)} - ${_formatPrice(priceMax!)}';
    }
    if (priceMin != null) return 'Từ ${_formatPrice(priceMin!)}';
    return 'Đến ${_formatPrice(priceMax!)}';
  }

  String get matchLabel {
    final score = similarityScore;
    if (score == null) return '';
    return '${(score * 100).round()}% hợp vibe';
  }

  static Map<String, dynamic> _metadataObject(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _categoryLabel(String category) {
    return switch (category.toLowerCase()) {
      'cafe' => 'Cà phê',
      'restaurant' => 'Nhà hàng',
      'hotel' => 'Khách sạn',
      'tourist_attraction' => 'Du lịch',
      'shopping' => 'Mua sắm',
      'office' => 'Văn phòng',
      _ => category,
    };
  }

  static String _formatPrice(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).round()}k';
    return '$valueđ';
  }
}

class AiSearchException implements Exception {
  final String message;

  const AiSearchException(this.message);

  @override
  String toString() => message;
}

class AiSearchService {
  final AuthService _authService;
  final http.Client _client;

  AiSearchService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<AiSearchResult> search({
    required String prompt,
    List<AiChatHistoryMessage> history = const <AiChatHistoryMessage>[],
    List<AiContextPlace> contextPlaces = const <AiContextPlace>[],
    int limit = 10,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw const AiSearchException('Bạn cần đăng nhập lại để dùng Fidey AI');
    }

    final response = await _client.post(
      Uri.parse('${Config.apiBaseUrl}/search'),
      headers: {'Authorization': token, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        'history': history.map((message) => message.toJson()).toList(),
        'contextPlaces': contextPlaces.map((place) => place.toJson()).toList(),
        'limit': limit,
      }),
    );

    final decoded = _decodeObject(response.body);
    if (response.statusCode == 200) {
      return AiSearchResult.fromJson(decoded);
    }

    if (response.statusCode == 429 && decoded['error'] == 'AI_QUOTA_EXCEEDED') {
      throw const AiSearchException(
        'Bạn đã dùng hết lượt AI hôm nay. Nâng cấp Pro hoặc quay lại vào ngày mai nhé.',
      );
    }

    debugPrint(
      '[AiSearchService] HTTP ${response.statusCode}: ${response.body}',
    );
    throw AiSearchException(
      decoded['error'] as String? ?? 'Không gọi được Fidey AI',
    );
  }

  Map<String, dynamic> _decodeObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
