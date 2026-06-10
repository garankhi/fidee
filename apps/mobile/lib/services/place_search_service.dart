import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'discovery_feed_service.dart';

class PlaceSearchService {
  const PlaceSearchService();

  Future<List<DiscoveryPlace>> search(String prompt) async {
    final response = await http.post(
      Uri.parse('${Config.apiBaseUrl}/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': prompt.trim()}),
    );
    if (response.statusCode != 200) {
      throw StateError('Không thể tìm kiếm địa điểm.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ((body['results'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(DiscoveryPlace.fromJson)
        .toList(growable: false);
  }
}
