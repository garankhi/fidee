import '../services/friend_service.dart';

enum CameraShareAudienceType { allFriends, direct }

class CameraShareAudience {
  final CameraShareAudienceType type;
  final String label;
  final List<String> friendIds;

  const CameraShareAudience._({
    required this.type,
    required this.label,
    this.friendIds = const <String>[],
  });

  factory CameraShareAudience.allFriends() {
    return const CameraShareAudience._(
      type: CameraShareAudienceType.allFriends,
      label: 'Tất cả',
    );
  }

  factory CameraShareAudience.friends(List<FriendProfile> friends) {
    final uniqueFriends = <String, FriendProfile>{
      for (final friend in friends) friend.id: friend,
    }.values.toList(growable: false);

    if (uniqueFriends.isEmpty) return CameraShareAudience.allFriends();

    return CameraShareAudience._(
      type: CameraShareAudienceType.direct,
      label: uniqueFriends.length == 1
          ? (uniqueFriends.first.handle.isNotEmpty
                ? uniqueFriends.first.handle
                : uniqueFriends.first.name)
          : '${uniqueFriends.length} bạn bè',
      friendIds: uniqueFriends
          .map((friend) => friend.id)
          .toList(growable: false),
    );
  }

  CameraShareAudience toggleFriend(
    FriendProfile friend,
    List<FriendProfile> availableFriends,
  ) {
    final selectedIds = friendIds.toSet();
    if (selectedIds.contains(friend.id)) {
      selectedIds.remove(friend.id);
    } else {
      selectedIds.add(friend.id);
    }

    final selectedFriends = availableFriends
        .where((item) => selectedIds.contains(item.id))
        .toList(growable: false);
    return CameraShareAudience.friends(selectedFriends);
  }

  Map<String, dynamic> toApiJson() {
    return switch (type) {
      CameraShareAudienceType.allFriends => <String, dynamic>{
        'type': 'ALL_FRIENDS',
      },
      CameraShareAudienceType.direct => <String, dynamic>{
        'type': 'DIRECT',
        'friendIds': friendIds,
      },
    };
  }
}
