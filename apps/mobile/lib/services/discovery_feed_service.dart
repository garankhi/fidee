import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'auth_service.dart';

/// A single place item returned from the discovery feed.
class DiscoveryPlace {
  final String placeId;
  final String name;
  final String? category;
  final double avgRating;
  final int ratingCount;
  final int checkinCount;
  final String? coverMediaId;
  final double lat;
  final double lng;
  final int distanceMeters;
  final bool isCandidate;
  final int? friendCheckinCount;
  final List<String> friendAvatars;
  final int? priceMin;
  final int? priceMax;

  const DiscoveryPlace({
    required this.placeId,
    required this.name,
    this.category,
    required this.avgRating,
    required this.ratingCount,
    required this.checkinCount,
    this.coverMediaId,
    required this.lat,
    required this.lng,
    required this.distanceMeters,
    required this.isCandidate,
    this.friendCheckinCount,
    this.friendAvatars = const [],
    this.priceMin,
    this.priceMax,
  });

  factory DiscoveryPlace.fromJson(Map<String, dynamic> json) {
    return DiscoveryPlace(
      placeId: json['placeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? 0,
      checkinCount: (json['checkinCount'] as num?)?.toInt() ?? 0,
      coverMediaId: json['coverMediaId'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toInt() ?? 0,
      isCandidate: json['isCandidate'] as bool? ?? false,
      friendCheckinCount: (json['friendCheckinCount'] as num?)?.toInt(),
      friendAvatars:
          (json['friendAvatars'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      priceMin: (json['priceMin'] as num?)?.toInt(),
      priceMax: (json['priceMax'] as num?)?.toInt(),
    );
  }

  String get categoryLabel {
    return switch (category?.toLowerCase()) {
      'cafe' || 'coffee' => 'Cà phê',
      'restaurant' || 'food' => 'Nhà hàng',
      'bar' || 'pub' => 'Bar',
      'bakery' || 'dessert' => 'Đồ ngọt',
      'fast_food' || 'fastfood' => 'Đồ ăn nhanh',
      _ => category ?? 'Địa điểm',
    };
  }

  String get priceLabel {
    if (priceMin == null && priceMax == null) return '';
    final formatter = _formatPrice;
    if (priceMin != null && priceMax != null) {
      return '${formatter(priceMin!)} – ${formatter(priceMax!)}đ';
    }
    if (priceMax != null) return 'đến ${formatter(priceMax!)}đ';
    return 'từ ${formatter(priceMin!)}đ';
  }

  String _formatPrice(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).round()}k';
    return value.toString();
  }
}

class DiscoveryFeedData {
  final List<DiscoveryPlace> hotPlaces;
  final List<DiscoveryPlace> recommendedPlaces;
  final List<DiscoveryPlace> friendsActivity;

  const DiscoveryFeedData({
    required this.hotPlaces,
    required this.recommendedPlaces,
    required this.friendsActivity,
  });

  factory DiscoveryFeedData.empty() => const DiscoveryFeedData(
    hotPlaces: [],
    recommendedPlaces: [],
    friendsActivity: [],
  );
}

class DiscoveryFeedService {
  final AuthService _authService;

  const DiscoveryFeedService(this._authService);

  Future<DiscoveryFeedData> fetchFeed({
    required double lat,
    required double lng,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return DiscoveryFeedData.empty();
    }

    try {
      final uri = Uri.parse(
        '${Config.apiBaseUrl}/discovery/feed?lat=$lat&lng=$lng',
      );
      final response = await http.get(uri, headers: {'Authorization': token});

      if (response.statusCode != 200) {
        debugPrint(
          '[DiscoveryFeedService] HTTP ${response.statusCode}: ${response.body}',
        );
        return DiscoveryFeedData.empty();
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>? ?? {};

      List<DiscoveryPlace> parse(String key) {
        return ((data[key] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DiscoveryPlace.fromJson)
            .toList(growable: false);
      }

      return DiscoveryFeedData(
        hotPlaces: parse('hotPlaces'),
        recommendedPlaces: parse('recommendedPlaces'),
        friendsActivity: parse('friendsActivity'),
      );
    } catch (e) {
      debugPrint('[DiscoveryFeedService] Error: $e');
      return DiscoveryFeedData.empty();
    }
  }
}
