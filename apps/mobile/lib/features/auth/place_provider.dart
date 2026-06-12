import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'place_provider.g.dart';

class Place {
  final String? id;
  final String? name;
  final String? category;
  final String? address;
  final double? lat;
  final double? lng;
  final String? openTime;
  final String? closeTime;
  final int? priceMin;
  final int? priceMax;
  final String? description;

  final double avgRating;
  final int ratingCount;
  final int checkinCount;

  final List<dynamic> friendCheckins;
  final List<dynamic> friendReviews;
  final List<dynamic> otherReviews;
  final List<dynamic> photos;
  final List<String> vibes;
  final List<String> services;

  const Place({
    this.id,
    this.name,
    this.category,
    this.address,
    this.lat,
    this.lng,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.description,
    this.avgRating = 0,
    this.ratingCount = 0,
    this.checkinCount = 0,
    this.friendCheckins = const [],
    this.friendReviews = const [],
    this.otherReviews = const [],
    this.photos = const [],
    this.vibes = const [],
    this.services = const [],
  });

  Place copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? lat,
    double? lng,
    String? openTime,
    String? closeTime,
    int? priceMin,
    int? priceMax,
    String? description,
    double? avgRating,
    int? ratingCount,
    int? checkinCount,
    List<dynamic>? friendCheckins,
    List<dynamic>? friendReviews,
    List<dynamic>? otherReviews,
    List<dynamic>? photos,
    List<String>? vibes,
    List<String>? services,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      description: description ?? this.description,
      avgRating: avgRating ?? this.avgRating,
      ratingCount: ratingCount ?? this.ratingCount,
      checkinCount: checkinCount ?? this.checkinCount,
      friendCheckins: friendCheckins ?? this.friendCheckins,
      friendReviews: friendReviews ?? this.friendReviews,
      otherReviews: otherReviews ?? this.otherReviews,
      photos: photos ?? this.photos,
      vibes: vibes ?? this.vibes,
      services: services ?? this.services,
    );
  }
}

String _formatTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '00:00';

  final parts = timeStr.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return timeStr;
}

@riverpod
class PlaceController extends _$PlaceController {
  @override
  Place build() => const Place();

  Future<void> fetchPlaceDetail(String placeId) async {
    final authService = ref.read(authServiceProvider);
    final token = await authService.getToken();

    const baseUrl = 'https://api.fidee.site/places';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$placeId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed');
      }

      final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;

      final data = jsonResult['data'] as Map<String, dynamic>? ?? {};

      final coordinates = data['coordinates'] as Map<String, dynamic>? ?? {};

      state = Place(
        id: data['id']?.toString(),
        name: data['name']?.toString(),
        category: data['category']?.toString(),
        address: data['address']?.toString(),

        lat: double.tryParse(coordinates['lat']?.toString() ?? '') ?? 0,

        lng: double.tryParse(coordinates['lng']?.toString() ?? '') ?? 0,

        openTime: _formatTime(data['openTime']?.toString()),
        closeTime: _formatTime(data['closeTime']?.toString()),

        priceMin: int.tryParse(data['priceMin']?.toString() ?? ''),

        priceMax: int.tryParse(data['priceMax']?.toString() ?? ''),

        description: data['description']?.toString(),

        avgRating: double.tryParse(data['avgRating']?.toString() ?? '') ?? 0,

        ratingCount: int.tryParse(data['ratingCount']?.toString() ?? '') ?? 0,

        checkinCount: int.tryParse(data['checkinCount']?.toString() ?? '') ?? 0,

        vibes: List<String>.from(data['vibes'] as Iterable? ?? []),
        services: List<String>.from(data['services'] as Iterable? ?? []),

        friendCheckins: List<dynamic>.from(
          data['friendCheckins'] as Iterable? ?? [],
        ),
        friendReviews: List<dynamic>.from(
          data['friendReviews'] as Iterable? ?? [],
        ),
        otherReviews: List<dynamic>.from(
          data['otherReviews'] as Iterable? ?? [],
        ),
        photos: List<dynamic>.from(data['photos'] as Iterable? ?? []),
      );
    } catch (e, stackTrace) {
      debugPrint('Place Detail Error: $e');
      debugPrint('Stack trace: $stackTrace');
      state = const Place();
    }
  }

  void clear() => state = const Place();
}

@riverpod
class PlaceFeedController extends _$PlaceFeedController {
  @override
  FutureOr<List<Place>> build() async {
    return _fetchPlacesFeed();
  }

  Future<List<Place>> _fetchPlacesFeed() async {
  final authService = ref.read(authServiceProvider);
  final token = await authService.getToken();

  // API Endpoint lấy danh sách Feed của MapVibe
  const url = 'https://api.fidee.site/places';

  try {
    final response = await http.get(
    Uri.parse(url),
    headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to load places feed');
  }

  final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;
  final dataList = jsonResult['data'] as List<dynamic>? ?? [];

  // Map trực tiếp sang Object Place dựa trên cấu trúc dữ liệu cũ của bạn
  return dataList.map((json) {
  final data = json as Map<String, dynamic>;
  final coordinates = data['coordinates'] as Map<String, dynamic>? ?? {};

  return Place(
    id: data['id']?.toString(),
    name: data['name']?.toString(),
    category: data['category']?.toString(),
    address: data['address']?.toString(),
    lat: double.tryParse(coordinates['lat']?.toString() ?? '') ?? 0,
    lng: double.tryParse(coordinates['lng']?.toString() ?? '') ?? 0,
    openTime: data['openTime']?.toString(),
    closeTime: data['closeTime']?.toString(),
    priceMin: int.tryParse(data['priceMin']?.toString() ?? ''),
    priceMax: int.tryParse(data['priceMax']?.toString() ?? ''),
    description: data['description']?.toString(),
    avgRating: double.tryParse(data['avgRating']?.toString() ?? '') ?? 0,
    ratingCount: int.tryParse(data['ratingCount']?.toString() ?? '') ?? 0,
    checkinCount: int.tryParse(data['checkinCount']?.toString() ?? '') ?? 0,
    vibes: List<String>.from(data['vibes'] as Iterable? ?? []),
    services: List<String>.from(data['services'] as Iterable? ?? []),
    friendCheckins: List<dynamic>.from(data['friendCheckins'] as Iterable? ?? []),
    friendReviews: List<dynamic>.from(data['friendReviews'] as Iterable? ?? []),
    otherReviews: List<dynamic>.from(data['otherReviews'] as Iterable? ?? []),
    photos: List<dynamic>.from(data['photos'] as Iterable? ?? []),
    );
    }).toList();

    } catch (e, stackTrace) {
    debugPrint('Error fetching places feed: $e\n$stackTrace');
    rethrow;
    }
  }

  // Hàm hỗ trợ kéo thả làm mới (Pull-to-refresh)
  Future<void> refreshFeed() async {
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() => _fetchPlacesFeed());
  }
}
