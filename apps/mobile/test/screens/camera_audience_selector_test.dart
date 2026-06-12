import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:fidee_mobile/screens/camera_audience_selector.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows current audience pill and opens dropdown', (tester) async {
    CameraFeedAudience? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: CameraAudienceSelector(
              selectedAudience: CameraFeedAudience.everyone(),
              friends: const <FriendProfile>[
                FriendProfile(id: 'friend-1', name: 'ahn', handle: 'ahn'),
              ],
              onSelected: (audience) => selected = audience,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Mọi người'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-audience-pill')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('camera-audience-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Bạn'), findsOneWidget);
    expect(find.text('ahn'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('camera-audience-friend-friend-1')),
    );
    await tester.pumpAndSettle();

    expect(selected?.type, CameraFeedAudienceType.friend);
    expect(selected?.id, 'friend-1');
  });
}
