import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/dashboard_place.dart';
import '../auth/auth_providers.dart';

part 'dashboard_provider.g.dart';

class DashboardState {
  final List<DashboardPlace> hotPlaces;
  final List<DashboardPlace> recommendedPlaces;
  final List<DashboardPlace> friendActivities;

  final List<Map<String, dynamic>> vibes;

  final String? selectedVibe;

  const DashboardState({
    this.hotPlaces = const [],
    this.recommendedPlaces = const [],
    this.friendActivities = const [],
    this.vibes = const [],
    this.selectedVibe,
  });

  DashboardState copyWith({
    List<DashboardPlace>? hotPlaces,
    List<DashboardPlace>? recommendedPlaces,
    List<DashboardPlace>? friendActivities,
    List<Map<String, dynamic>>? vibes,
    String? selectedVibe,
  }) {
    return DashboardState(
      hotPlaces: hotPlaces ?? this.hotPlaces,
      recommendedPlaces: recommendedPlaces ?? this.recommendedPlaces,
      friendActivities: friendActivities ?? this.friendActivities,
      vibes: vibes ?? this.vibes,
      selectedVibe: selectedVibe ?? this.selectedVibe,
    );
  }
}

@riverpod
class DashboardController extends _$DashboardController {
  @override
  DashboardState build() {
    Future.microtask(loadDiscoveryFeed);
    return const DashboardState();
  }

  Future<void> loadDiscoveryFeed() async {
    final authService = ref.read(authServiceProvider);
    final token = await authService.getToken();

    try {
      const lat = 10.7769;
      const lng = 106.7009;

      final response = await http.get(
        Uri.parse('https://api.fidee.site/discovery/feed?lat=$lat&lng=$lng'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode != 200) {
        return;
      }

      final jsonResult = jsonDecode(response.body) as Map<String, dynamic>;

      final data = jsonResult['data'] as Map<String, dynamic>? ?? {};

      final hotPlaces = (data['hotPlaces'] as List<dynamic>? ?? [])
          .map(
            (e) => DashboardPlace.fromJson(
              _convertPlace(e as Map<String, dynamic>),
            ),
          )
          .toList();

      final recommendedPlaces =
          (data['recommendedPlaces'] as List<dynamic>? ?? [])
              .map(
                (e) => DashboardPlace.fromJson(
                  _convertPlace(e as Map<String, dynamic>),
                ),
              )
              .toList();

      final friendActivities = (data['friendsActivity'] as List<dynamic>? ?? [])
          .map(
            (e) => DashboardPlace.fromJson(
              _convertFriendPlace(e as Map<String, dynamic>),
            ),
          )
          .toList();

      final vibes = (data['vibes'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      state = state.copyWith(
        hotPlaces: hotPlaces,
        recommendedPlaces: recommendedPlaces,
        friendActivities: friendActivities,
        vibes: vibes,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load discovery feed.',
        name: 'DashboardController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void selectVibe(String vibe) {
    state = state.copyWith(selectedVibe: vibe);
  }

  Map<String, dynamic> _convertPlace(Map<String, dynamic> item) {
    return {
      'id': item['placeId'],
      'name': item['name'],
      'category': item['category'],
      'avg_rating': item['avgRating'],
      'checkin_count': item['checkinCount'],
      'distance_meters': item['distanceMeters'],
      'metadata': {'image_url': _buildImageUrl(item['coverMediaId'])},
    };
  }

  Map<String, dynamic> _convertFriendPlace(Map<String, dynamic> item) {
    return {
      'id': item['placeId'],
      'name': item['name'],
      'category': item['category'],
      'avg_rating': item['avgRating'],
      'checkin_count': item['friendCheckinCount'],
      'distance_meters': item['distanceMeters'],
      'metadata': {'image_url': _buildImageUrl(item['coverMediaId'])},
    };
  }

  String _buildImageUrl(dynamic mediaId) {
    if (mediaId == null) {
      return 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500';
    }

    return 'https://api.fidee.site/media/$mediaId';
  }
}
