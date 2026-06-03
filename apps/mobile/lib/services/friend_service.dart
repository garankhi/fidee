import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

class FriendProfile {
  final String id;
  final String name;
  final String handle;
  final String? avatarUrl;

  const FriendProfile({
    required this.id,
    required this.name,
    required this.handle,
    this.avatarUrl,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> json) {
    return FriendProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      handle: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  String get initials {
    final List<String> pieces = name.trim().split(RegExp(r'\s+'));
    if (pieces.isEmpty || pieces.first.isEmpty) return '?';

    final String first = pieces.first.substring(0, 1);
    final String last = pieces.length < 2 ? '' : pieces.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }
}

class FriendService {
  final AuthService _authService;

  const FriendService(this._authService);

  Future<List<FriendProfile>> fetchFriends() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const <FriendProfile>[];
    }

    try {
      final response = await http.get(
        Uri.parse('${Config.apiBaseUrl}/friends'),
        headers: {'Authorization': token},
      );

      if (response.statusCode != 200) {
        return const <FriendProfile>[];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = (decoded['data'] as List<dynamic>?) ?? const <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => FriendProfile(
              id: item['id'] as String,
              name: item['display_name'] as String? ?? item['username'] as String? ?? 'Friend',
              handle: item['username'] as String? ?? '',
              avatarUrl: item['avatar_url'] as String?,
            ),
          )
          .toList(growable: false);
    } catch (error) {
      debugPrint('Error fetching friends: $error');
      return const <FriendProfile>[];
    }
  }
}
