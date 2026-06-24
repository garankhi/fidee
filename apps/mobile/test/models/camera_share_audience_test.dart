import 'package:fidee_mobile/models/camera_share_audience.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all friends maps to ALL_FRIENDS API payload', () {
    expect(CameraShareAudience.allFriends().toApiJson(), {
      'type': 'ALL_FRIENDS',
    });
  });

  test('multiple selected friends map to DIRECT API payload', () {
    final audience = CameraShareAudience.friends(const <FriendProfile>[
      FriendProfile(
        id: 'friend-1',
        name: 'Test Api',
        handle: 'testapi@fidee.com',
      ),
      FriendProfile(id: 'friend-2', name: 'Minh Nguyen', handle: 'minh'),
    ]);

    expect(audience.label, '2 bạn bè');
    expect(audience.toApiJson(), {
      'type': 'DIRECT',
      'friendIds': ['friend-1', 'friend-2'],
    });
  });

  test(
    'toggling friends supports multi-select and falls back to all friends',
    () {
      const friends = <FriendProfile>[
        FriendProfile(
          id: 'friend-1',
          name: 'Test Api',
          handle: 'testapi@fidee.com',
        ),
        FriendProfile(id: 'friend-2', name: 'Minh Nguyen', handle: 'minh'),
      ];

      final firstSelected = CameraShareAudience.allFriends().toggleFriend(
        friends[0],
        friends,
      );
      final twoSelected = firstSelected.toggleFriend(friends[1], friends);
      final oneRemaining = twoSelected.toggleFriend(friends[0], friends);
      final allFriends = oneRemaining.toggleFriend(friends[1], friends);

      expect(firstSelected.friendIds, ['friend-1']);
      expect(twoSelected.friendIds, ['friend-1', 'friend-2']);
      expect(oneRemaining.friendIds, ['friend-2']);
      expect(allFriends.type, CameraShareAudienceType.allFriends);
    },
  );
}
