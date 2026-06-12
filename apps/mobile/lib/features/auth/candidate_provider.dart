import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'auth_providers.dart';

part 'candidate_provider.g.dart';

class CandidatePlace {
  final String id;
  final String? name;
  final String? category;
  final String? address;

  final double lat;
  final double lng;

  final String? description;
  final String? mediaId;

  final double distanceKm;
  final int distanceMeters;

  final String? createdByName;
  final String? createdByUsername;
  final String? createdByAvatar;

  const CandidatePlace({
    required this.id,
    this.name,
    this.category,
    this.address,
    required this.lat,
    required this.lng,
    this.description,
    this.mediaId,
    required this.distanceKm,
    required this.distanceMeters,
    this.createdByName,
    this.createdByUsername,
    this.createdByAvatar,
  });

  factory CandidatePlace.fromJson(Map<String, dynamic> json) {
    final coordinates =
        json['coordinates'] as Map<String, dynamic>? ?? {};

    final createdBy =
        json['createdByInfo'] as Map<String, dynamic>? ?? {};

    return CandidatePlace(
      id: json['id'].toString(),
      name: json['name']?.toString(),
      category: json['category']?.toString(),
      address: json['address']?.toString(),

      lat: double.tryParse(
        coordinates['lat']?.toString() ?? '',
      ) ??
          0,

      lng: double.tryParse(
        coordinates['lng']?.toString() ?? '',
      ) ??
          0,

      description: json['description']?.toString(),
      mediaId: json['mediaId']?.toString(),

      distanceKm:
      double.tryParse(json['distanceKm']?.toString() ?? '') ??
          0,

      distanceMeters:
      int.tryParse(
        json['distanceMeters']?.toString() ?? '',
      ) ??
          0,

      createdByName: createdBy['displayName']?.toString(),
      createdByUsername: createdBy['username']?.toString(),
      createdByAvatar: createdBy['avatarUrl']?.toString(),
    );
  }
}

@riverpod
class CandidateController extends _$CandidateController {
  @override
  FutureOr<List<CandidatePlace>> build() async {
    return [];
  }

  Future<void> loadCandidates({
    required double lat,
    required double lng,
    double radiusKm = 20,
  }) async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final authService = ref.read(authServiceProvider);
      final token = await authService.getToken();

      final uri = Uri.parse(
        'https://api.fidee.site/candidates',
      ).replace(
        queryParameters: {
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusKm': radiusKm.toString(),
        },
      );

      debugPrint(uri.toString());
      debugPrint('TOKEN = $token');


      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      debugPrint('STATUS = ${response.statusCode}');
      debugPrint('BODY = ${response.body}');

      if (response.statusCode != 200) {
        debugPrint(response.body);

        throw Exception(
          'Failed to load candidates: ${response.statusCode} - ${response.body}',
        );
      }

      final jsonResult =
      jsonDecode(response.body) as Map<String, dynamic>;

      final data =
          jsonResult['data'] as List<dynamic>? ?? [];

      return data
          .map(
            (e) => CandidatePlace.fromJson(
          e as Map<String, dynamic>,
        ),
      )
          .toList();
    });
  }

  Future<void> refresh({
    required double lat,
    required double lng,
    double radiusKm = 20,
  }) async {
    await loadCandidates(
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );
  }
}