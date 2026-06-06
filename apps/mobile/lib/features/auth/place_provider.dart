import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/foundation.dart';

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
    );
  }
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

        openTime: data['openTime']?.toString(),
        closeTime: data['closeTime']?.toString(),

        priceMin: int.tryParse(data['priceMin']?.toString() ?? ''),

        priceMax: int.tryParse(data['priceMax']?.toString() ?? ''),

        description: data['description']?.toString(),

        avgRating: double.tryParse(data['avgRating']?.toString() ?? '') ?? 0,

        ratingCount: int.tryParse(data['ratingCount']?.toString() ?? '') ?? 0,

        checkinCount: int.tryParse(data['checkinCount']?.toString() ?? '') ?? 0,

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
