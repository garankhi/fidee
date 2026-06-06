import 'package:fidee_mobile/screens/camera_friends_sheet.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final friends = List<FriendProfile>.generate(
    5,
    (index) => FriendProfile(
      id: 'friend-$index',
      name: 'Friend $index',
      handle: 'friend$index',
    ),
  );

  Widget buildContent({
    Future<List<FriendSearchResult>> Function(String username)? onSearchUsers,
    Future<bool> Function(String userId)? onAddFriend,
    Future<bool> Function(String userId)? onHideFriend,
    Future<bool> Function(String userId)? onUnfriend,
    Future<bool> Function(String userId)? onBlockFriend,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CameraFriendsSheetContent(
          friends: friends,
          isLoading: false,
          onSearchUsers: onSearchUsers ?? (_) async => const <FriendSearchResult>[],
          onAddFriend: onAddFriend ?? (_) async => true,
          onHideFriend: onHideFriend ?? (_) async => true,
          onUnfriend: onUnfriend ?? (_) async => true,
          onBlockFriend: onBlockFriend ?? (_) async => true,
        ),
      ),
    );
  }

  testWidgets('shows three friends by default and expands then collapses', (tester) async {
    await tester.pumpWidget(buildContent());

    expect(find.text('5 người bạn'), findsOneWidget);
    expect(find.text('Friend 0'), findsOneWidget);
    expect(find.text('Friend 1'), findsOneWidget);
    expect(find.text('Friend 2'), findsOneWidget);
    expect(find.text('Friend 3'), findsNothing);
    expect(find.text('Xem thêm'), findsOneWidget);

    await tester.tap(find.text('Xem thêm'));
    await tester.pumpAndSettle();

    expect(find.text('Friend 4', skipOffstage: false), findsOneWidget);
    expect(find.text('Rút gọn', skipOffstage: false), findsOneWidget);

    await tester.ensureVisible(find.text('Rút gọn', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rút gọn'));
    await tester.pumpAndSettle();

    expect(find.text('Friend 3'), findsNothing);
    expect(find.text('Xem thêm'), findsOneWidget);
  });

  testWidgets('opens friend action popup from x button', (tester) async {
    await tester.pumpWidget(buildContent());

    await tester.tap(find.byKey(const ValueKey('friend-action-friend-0')));
    await tester.pumpAndSettle();

    expect(find.text('Ẩn bạn bè'), findsOneWidget);
    expect(find.text('Xóa bạn'), findsOneWidget);
    expect(find.text('Chặn bạn bè'), findsOneWidget);
  });

  testWidgets('searches by username and sends friend request', (tester) async {
    String? addedUserId;

    await tester.pumpWidget(
      buildContent(
        onSearchUsers: (username) async {
          expect(username, 'minh');
          return const <FriendSearchResult>[
            FriendSearchResult(
              profile: FriendProfile(id: 'user-2', name: 'Minh Tran', handle: 'minh'),
              relationStatus: FriendRelationStatus.none,
              canRequest: true,
            ),
          ];
        },
        onAddFriend: (userId) async {
          addedUserId = userId;
          return true;
        },
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('friend-search-field')), 'minh');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.text('Minh Tran'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-add-user-2')));
    await tester.pump();
    await tester.pump();

    expect(addedUserId, 'user-2');
  });
}