import 'package:fidee_mobile/features/friends/widgets/friend_request_widgets.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('badge hides at zero and formats large counts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            FriendRequestBadge(count: 0),
            FriendRequestBadge(count: 120),
          ],
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('summary banner opens from tap and action', (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendRequestSummaryBanner(count: 2, onOpen: () => opens += 1),
        ),
      ),
    );

    expect(find.text('Bạn có 2 lời mời kết bạn'), findsOneWidget);
    await tester.tap(find.byType(FriendRequestSummaryBanner));
    await tester.pump();
    await tester.tap(find.text('Xem'));

    expect(opens, 2);
  });

  testWidgets('action row invokes accept and decline callbacks', (
    tester,
  ) async {
    var accepted = false;
    var declined = false;
    const request = FriendProfile(
      id: 'request-1',
      name: 'Lan Tran',
      handle: 'lan',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendRequestActionRow(
            request: request,
            tone: FriendRequestTone.light,
            isBusy: false,
            onAccept: () => accepted = true,
            onDecline: () => declined = true,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('friend-request-accept-request-1')),
    );
    await tester.tap(
      find.byKey(const ValueKey('friend-request-decline-request-1')),
    );

    expect(accepted, isTrue);
    expect(declined, isTrue);
  });
}
