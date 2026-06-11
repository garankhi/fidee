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
    List<FriendProfile> requests = const <FriendProfile>[],
    Future<List<FriendSearchResult>> Function(String username)? onSearchUsers,
    Future<bool> Function(String userId)? onAddFriend,
    Future<bool> Function(String userId)? onCancelFriendRequest,
    Future<bool> Function(String userId)? onAcceptFriend,
    Future<bool> Function(String userId)? onDeclineFriend,
    Future<bool> Function(String userId)? onHideFriend,
    Future<bool> Function(String userId)? onUnfriend,
    Future<bool> Function(String userId)? onBlockFriend,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CameraFriendsSheetContent(
          friends: friends,
          requests: requests,
          isLoading: false,
          onSearchUsers: onSearchUsers ?? (_) async => const <FriendSearchResult>[],
          onAddFriend: onAddFriend ?? (_) async => true,
          onCancelFriendRequest: onCancelFriendRequest ?? (_) async => true,
          onAcceptFriend: onAcceptFriend ?? (_) async => true,
          onDeclineFriend: onDeclineFriend ?? (_) async => true,
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
    expect(find.text('Hủy gửi'), findsOneWidget);
  });

  testWidgets('cancels an outgoing request from search results', (tester) async {
    String? canceledUserId;

    await tester.pumpWidget(
      buildContent(
        onSearchUsers: (_) async {
          return const <FriendSearchResult>[
            FriendSearchResult(
              profile: FriendProfile(id: 'user-2', name: 'Minh Tran', handle: 'minh'),
              relationStatus: FriendRelationStatus.pending,
              relationDirection: FriendRelationDirection.outgoing,
              canRequest: false,
              canCancelRequest: true,
            ),
          ];
        },
        onCancelFriendRequest: (userId) async {
          canceledUserId = userId;
          return true;
        },
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('friend-search-field')), 'minh');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('friend-cancel-user-2')));
    await tester.pump();
    await tester.pump();

    expect(canceledUserId, 'user-2');
    expect(find.text('Thêm'), findsOneWidget);
  });

  testWidgets('shows pending friend requests and accepts one', (tester) async {
    String? acceptedUserId;

    await tester.pumpWidget(
      buildContent(
        requests: const <FriendProfile>[
          FriendProfile(id: 'request-1', name: 'Lan Tran', handle: 'lan'),
        ],
        onAcceptFriend: (userId) async {
          acceptedUserId = userId;
          return true;
        },
      ),
    );

    expect(find.text('Lời mời kết bạn'), findsOneWidget);
    expect(find.text('Lan Tran'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-request-accept-request-1')));
    await tester.pump();
    await tester.pump();

    expect(acceptedUserId, 'request-1');
    expect(find.text('Đã chấp nhận lời mời'), findsOneWidget);
  });

  testWidgets('declines a pending friend request', (tester) async {
    String? declinedUserId;

    await tester.pumpWidget(
      buildContent(
        requests: const <FriendProfile>[
          FriendProfile(id: 'request-2', name: 'Bao Le', handle: 'bao'),
        ],
        onDeclineFriend: (userId) async {
          declinedUserId = userId;
          return true;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('friend-request-decline-request-2')));
    await tester.pump();
    await tester.pump();

    expect(declinedUserId, 'request-2');
    expect(find.text('Đã từ chối lời mời'), findsOneWidget);
  });
}
