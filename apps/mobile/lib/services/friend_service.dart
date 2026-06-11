import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'auth_service.dart';

enum FriendRelationStatus { none, pending, accepted, blocked, unknown }

FriendRelationStatus friendRelationStatusFromApi(String? value) {
  switch (value?.toUpperCase()) {
    case 'NONE':
      return FriendRelationStatus.none;
    case 'PENDING':
      return FriendRelationStatus.pending;
    case 'ACCEPTED':
      return FriendRelationStatus.accepted;
    case 'BLOCKED':
      return FriendRelationStatus.blocked;
    default:
      return FriendRelationStatus.unknown;
  }
}

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
      name:
          json['name'] as String? ??
          json['displayName'] as String? ??
          json['display_name'] as String? ??
          json['username'] as String? ??
          'Friend',
      handle: json['username'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
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

class FriendSearchResult {
  final FriendProfile profile;
  final FriendRelationStatus relationStatus;
  final bool canRequest;

  const FriendSearchResult({
    required this.profile,
    required this.relationStatus,
    required this.canRequest,
  });

  factory FriendSearchResult.fromJson(Map<String, dynamic> json) {
    final status = friendRelationStatusFromApi(
      json['relationStatus'] as String? ?? json['status'] as String?,
    );
    return FriendSearchResult(
      profile: FriendProfile.fromJson(json),
      relationStatus: status,
      canRequest:
          json['canRequest'] as bool? ?? status == FriendRelationStatus.none,
    );
  }
}

class FriendService {
  final AuthService _authService;
  final http.Client _client;

  FriendService(this._authService, {http.Client? client})
    : _client = client ?? http.Client();

  Future<List<FriendProfile>> fetchFriends() async {
    return _fetchProfiles(
      path: '/friends',
      listKey: 'friends',
      fallbackListKey: 'data',
      debugLabel: 'friends',
    );
  }

  Future<List<FriendProfile>> fetchFriendRequests() async {
    return _fetchProfiles(
      path: '/friends/requests',
      listKey: 'requests',
      debugLabel: 'friend requests',
    );
  }

  Future<List<FriendSearchResult>> searchUsersByUsername(
    String username,
  ) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const <FriendSearchResult>[];
    }

    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isEmpty) {
      return const <FriendSearchResult>[];
    }

    try {
      final uri = Uri.parse(
        '${Config.apiBaseUrl}/friends/search',
      ).replace(queryParameters: {'username': normalizedUsername});
      final response = await _client.get(
        uri,
        headers: {'Authorization': token},
      );

      if (response.statusCode != 200) {
        return const <FriendSearchResult>[];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final itemList =
          (decoded['users'] as List<dynamic>?) ??
          (decoded['data'] as List<dynamic>?) ??
          const <dynamic>[];
      return itemList
          .whereType<Map<String, dynamic>>()
          .map(FriendSearchResult.fromJson)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Error searching friends: $error');
      return const <FriendSearchResult>[];
    }
  }

  Future<bool> sendFriendRequest(String userId) {
    return _postFriendAction('/friends/request', userId);
  }

  Future<bool> acceptFriend(String userId) {
    return _postFriendAction('/friends/accept', userId);
  }

  Future<bool> declineFriend(String userId) {
    return _postFriendAction('/friends/decline', userId);
  }

  Future<bool> unfriend(String userId) {
    return _postFriendAction('/friends/unfriend', userId);
  }

  Future<bool> hideFriend(String userId) {
    return _postFriendAction('/friends/hide', userId);
  }

  Future<bool> blockFriend(String userId) {
    return _postFriendAction('/friends/block', userId);
  }

  Future<List<FriendProfile>> _fetchProfiles({
    required String path,
    required String listKey,
    String? fallbackListKey,
    required String debugLabel,
  }) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return const <FriendProfile>[];
    }

    try {
      final response = await _client.get(
        Uri.parse('${Config.apiBaseUrl}$path'),
        headers: {'Authorization': token},
      );

      if (response.statusCode != 200) {
        return const <FriendProfile>[];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      dynamic items = decoded[listKey];
      if (items == null && fallbackListKey != null) {
        items = decoded[fallbackListKey];
      }
      final itemList = (items as List<dynamic>?) ?? const <dynamic>[];
      return itemList
          .whereType<Map<String, dynamic>>()
          .map(FriendProfile.fromJson)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Error fetching $debugLabel: $error');
      return const <FriendProfile>[];
    }
  }

  Future<bool> _postFriendAction(String path, String userId) async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await _client.post(
        Uri.parse('${Config.apiBaseUrl}$path'),
        headers: {'Authorization': token, 'Content-Type': 'application/json'},
        body: jsonEncode({'targetUserId': userId}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final decoded = response.body.isEmpty
          ? <String, dynamic>{'success': true}
          : jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['success'] == true;
    } catch (error) {
      debugPrint('Error posting friend action $path: $error');
      return false;
    }
  }
}
