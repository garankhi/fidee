import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'candidate_provider.g.dart';

class CandidatePlace {
  final String id;
  final String? name;
  final String? normalizedName;
  final String? category;
  final String? address;

  final double lat;
  final double lng;

  final String? mediaId;
  final String? openTime;
  final String? closeTime;
  final double? priceMin;
  final double? priceMax;
  final String? phoneNumber;
  final String? description;
  final String? status;
  final String? createdAt;
  final String? createdBy;

  final String? createdByName;
  final String? createdByUsername;
  final String? createdByAvatar;

  final double distanceKm;
  final int distanceMeters;

  const CandidatePlace({
    required this.id,
    this.name,
    this.normalizedName,
    this.category,
    this.address,
    required this.lat,
    required this.lng,
    this.mediaId,
    this.openTime,
    this.closeTime,
    this.priceMin,
    this.priceMax,
    this.phoneNumber,
    this.description,
    this.status,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.createdByUsername,
    this.createdByAvatar,
    required this.distanceKm,
    required this.distanceMeters,
  });

  factory CandidatePlace.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as Map<String, dynamic>? ?? {};

    final createdBy = json['createdByInfo'] as Map<String, dynamic>? ?? {};

    return CandidatePlace(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString(),
      normalizedName: json['normalized_name']?.toString(),
      category: json['category']?.toString(),
      address: json['address']?.toString(),

      lat: double.tryParse(coordinates['lat']?.toString() ?? '') ?? 0,

      lng: double.tryParse(coordinates['lng']?.toString() ?? '') ?? 0,

      mediaId: json['media_id']?.toString(),
      openTime: json['open_time']?.toString(),
      closeTime: json['close_time']?.toString(),
      priceMin: double.tryParse(json['price_min']?.toString() ?? ''),
      priceMax: double.tryParse(json['price_max']?.toString() ?? ''),
      phoneNumber: json['phone_number']?.toString(),
      description: json['description']?.toString(),
      mediaId: json['mediaId']?.toString(),

      distanceKm: double.tryParse(json['distanceKm']?.toString() ?? '') ?? 0,

      distanceMeters:
          int.tryParse(json['distanceMeters']?.toString() ?? '') ?? 0,

      distanceKm: 0.0,
      distanceMeters: 0,
    );
  }
}

@riverpod
class CandidateController extends _$CandidateController {
  @override
  FutureOr<List<CandidatePlace>> build() async {
    return [];
  }

  Future<void> loadCandidates({String? status}) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getToken();

      final uri = Uri.parse('https://api.fidee.site/candidates').replace(
        queryParameters: {
          if (status != null) 'status': status,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 200) {
        debugPrint(response.body);
        throw Exception(
          'Failed to load candidates: ${response.statusCode} - ${response.body}',
        );
      }

      final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;

      final data = jsonResult['data'] as List<dynamic>? ?? [];

      return data
          .map((e) => CandidatePlace.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> refresh({
    required double lat,
    required double lng,
    double radiusKm = 20,
  }) async {
    await loadCandidates(lat: lat, lng: lng, radiusKm: radiusKm);
  }
}
