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

  Future<List<MapFeedItem>> getMapFeed(double lat, double lng, {int radius = 5000}) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final uri = Uri.parse('$_baseUrl/map/feed?lat=$lat&lng=$lng&radius=$radius');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': token,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = (data['data'] as List<dynamic>?) ?? [];
        return items.map((e) => MapFeedItem.fromJson(e as Map<String, dynamic>)).toList();
      } else {
        // Fallback to mock data for now during development if API is not fully deployed
        return _getMockData(lat, lng);
      }
    } catch (e) {
      debugPrint('Error fetching map feed: $e');
      return _getMockData(lat, lng);
    }
  }

  // Temporary mock data for UI development before DB is populated
  List<MapFeedItem> _getMockData(double lat, double lng) {
    return [
      MapFeedItem(
        id: '1',
        caption: 'Cà phê cực chill nha mọi người!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        mediaId: 'mock_media_1',
        userId: 'user_2',
        userName: 'Hân Nguyễn',
        placeId: 'p1',
        placeName: 'The Local Cafe',
        category: 'cafe',
        lat: lat + 0.001,
        lng: lng + 0.001,
      ),
      MapFeedItem(
        id: '2',
        caption: 'Phở ngon nhất quận',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        mediaId: 'mock_media_2',
        userId: 'user_3',
        userName: 'Tuấn Trần',
        placeId: 'p2',
        placeName: 'Phở Hùng',
        category: 'restaurant',
        lat: lat - 0.002,
        lng: lng + 0.002,
      ),
      MapFeedItem(
        id: '3',
        caption: 'Check in quán ruột của mình',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        mediaId: 'mock_media_3',
        userId: _authService.username ?? 'self',
        userName: _authService.username ?? 'Tôi',
        placeId: 'p3',
        placeName: 'Katinat',
        category: 'cafe',
        lat: lat - 0.001,
        lng: lng - 0.001,
      ),
    ];
  }
}
