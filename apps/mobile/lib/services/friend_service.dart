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

  String get initials {
    final List<String> pieces = name.trim().split(RegExp(r'\s+'));
    if (pieces.isEmpty || pieces.first.isEmpty) return '?';

    final String first = pieces.first.substring(0, 1);
    final String last = pieces.length < 2 ? '' : pieces.last.substring(0, 1);
    return '$first$last'.toUpperCase();
  }
}

class FriendService {
  const FriendService();

  /// Fetches the signed-in user's friends from the backend/database.
  ///
  /// The friends database/API is not available in mobile yet, so this returns
  /// an empty result instead of local placeholder people.
  Future<List<FriendProfile>> fetchFriends() async {
    return const <FriendProfile>[];
  }
}
