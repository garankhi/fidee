import 'package:fidey_mobile/models/camera_share_audience.dart';
import 'package:fidey_mobile/screens/send_image_preview_widgets.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects all or multiple friends for preview sharing', (
    tester,
  ) async {
    var selected = CameraShareAudience.allFriends();
    const friends = <FriendProfile>[
      FriendProfile(
        id: 'friend-1',
        name: 'Test Api',
        handle: 'testapi@fidee.com',
      ),
      FriendProfile(id: 'friend-2', name: 'Minh Nguyen', handle: 'minh'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: StatefulBuilder(
            builder: (context, setState) {
              return SendImageShareAudienceSelector(
                selectedAudience: selected,
                friends: friends,
                onSelected: (audience) => setState(() => selected = audience),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Cùng với'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('testapi@fidee.com'), findsOneWidget);
    expect(find.text('minh'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('send-image-audience-friend-friend-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('send-image-audience-friend-friend-2')),
    );
    await tester.pumpAndSettle();

    expect(selected.type, CameraShareAudienceType.direct);
    expect(selected.friendIds, ['friend-1', 'friend-2']);

    await tester.tap(find.byKey(const ValueKey('send-image-audience-all')));
    await tester.pumpAndSettle();

    expect(selected.type, CameraShareAudienceType.allFriends);
  });
}
