import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/map_feed_item.dart';
import 'auth_service.dart';

class MapFeedService {
  final AuthService _authService;
  static const String _baseUrl = Config.apiBaseUrl;

  MapFeedService(this._authService);

  Future<List<MapFeedItem>> getMapFeed(
    double lat,
    double lng, {
    int radius = 5000,
  }) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final uri = Uri.parse(
        '$_baseUrl/map/feed?lat=$lat&lng=$lng&radius=$radius',
      );
      final response = await http.get(uri, headers: {'Authorization': token});

      if (response.statusCode != 200) {
        return const <MapFeedItem>[];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = (data['data'] as List<dynamic>?) ?? [];
      return items
          .map((e) => MapFeedItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      debugPrint('Error fetching map feed: $error');
      return const <MapFeedItem>[];
    }
  }
}
