import 'package:fidey_mobile/features/friends/widgets/friend_request_widgets.dart';
import 'package:fidey_mobile/features/friends/widgets/friend_search_result_action_row.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows cancel action for outgoing pending search result', (
    tester,
  ) async {
    var canceled = false;
    const result = FriendSearchResult(
      profile: FriendProfile(id: 'user-2', name: 'Minh Tran', handle: 'minh'),
      relationStatus: FriendRelationStatus.pending,
      relationDirection: FriendRelationDirection.outgoing,
      canRequest: false,
      canCancelRequest: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FriendSearchResultActionRow(
            result: result,
            tone: FriendRequestTone.light,
            isBusy: false,
            onCancel: () => canceled = true,
          ),
        ),
      ),
    );

    expect(find.text('Hủy gửi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('friend-cancel-user-2')));

    expect(canceled, isTrue);
  });
}
