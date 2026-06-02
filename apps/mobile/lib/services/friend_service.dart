import 'dart:convert';
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
  final AuthService? _authService;
  static const String _baseUrl = Config.apiBaseUrl;

  const FriendService([this._authService]);

  Future<List<FriendProfile>> fetchFriends() async {
    final token = await _authService?.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/friends'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items = data['friends'] as List<dynamic>? ?? const [];
        return items.map((e) => FriendProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<FriendProfile>> fetchFriendRequests() async {
    final token = await _authService?.getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/friends/requests'),
        headers: {'Authorization': token},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> items = data['requests'] as List<dynamic>? ?? const [];
        return items.map((e) => FriendProfile.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> sendFriendRequest(String targetUserId) async {
    final token = await _authService?.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/friends/request'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> acceptFriend(String targetUserId) async {
    final token = await _authService?.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/friends/accept'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> declineFriend(String targetUserId) async {
    final token = await _authService?.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/friends/decline'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  Future<bool> unfriend(String targetUserId) async {
    final token = await _authService?.getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/friends/unfriend'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'targetUserId': targetUserId}),
      );
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}
