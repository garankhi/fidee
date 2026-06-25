import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/features/auth/friends_provider.dart';
import 'package:fidey_mobile/screens/friends_detail_screen.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(isTestMode: true);

  @override
  String? get preferredUsername => 'minh';
}

class _RequestsFriendsController extends FriendsController {
  String? acceptedUserId;
  String? canceledUserId;

  @override
  FriendsState build() {
    return const FriendsState(
      requests: [
        FriendProfile(id: 'request-1', name: 'Lan Tran', handle: 'lan'),
      ],
      sentRequests: [
        FriendProfile(id: 'sent-1', name: 'Bao Le', handle: 'bao'),
      ],
    );
  }

  @override
  Future<bool> accept(String userId) async {
    acceptedUserId = userId;
    return true;
  }

  @override
  Future<bool> cancelFriendRequest(String userId) async {
    canceledUserId = userId;
    state = state.copyWith(sentRequests: const <FriendProfile>[]);
    return true;
  }
}

class _SearchRefreshFriendsController extends FriendsController {
  var _searchCount = 0;

  @override
  FriendsState build() => const FriendsState(revision: 0);

  @override
  Future<List<FriendSearchResult>> searchUsers(String username) async {
    _searchCount += 1;
    if (_searchCount == 1) {
      return const <FriendSearchResult>[
        FriendSearchResult(
          profile: FriendProfile(id: 'user-2', name: 'Tran An', handle: 'tran'),
          relationStatus: FriendRelationStatus.accepted,
          canRequest: false,
        ),
      ];
    }

    return const <FriendSearchResult>[
      FriendSearchResult(
        profile: FriendProfile(id: 'user-2', name: 'Tran An', handle: 'tran'),
        relationStatus: FriendRelationStatus.none,
        canRequest: true,
      ),
    ];
  }

  void bumpRevisionForTesting() {
    state = state.copyWith(revision: state.revision + 1);
  }
}

void main() {
  testWidgets('accepts a pending request from friends detail', (tester) async {
    final friendsController = _RequestsFriendsController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          friendsControllerProvider.overrideWith(() => friendsController),
        ],
        child: const MaterialApp(home: FriendsDetailScreen()),
      ),
    );

    expect(find.text('Lời mời kết bạn'), findsOneWidget);
    expect(find.text('Lan Tran'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('friend-request-accept-request-1')),
    );
    await tester.pump();

    expect(friendsController.acceptedUserId, 'request-1');
    expect(find.text('Đã chấp nhận lời mời'), findsOneWidget);
  });

  testWidgets('shows sent requests and cancels one from friends detail', (
    tester,
  ) async {
    final friendsController = _RequestsFriendsController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          friendsControllerProvider.overrideWith(() => friendsController),
        ],
        child: const MaterialApp(home: FriendsDetailScreen()),
      ),
    );

    expect(find.text('Lời mời đã gửi'), findsOneWidget);
    expect(find.text('Bao Le'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('friend-cancel-sent-1')));
    await tester.pump();

    expect(friendsController.canceledUserId, 'sent-1');
    expect(find.text('Đã hủy lời mời kết bạn'), findsOneWidget);
  });

  testWidgets('refreshes active search results when friends revision changes', (
    tester,
  ) async {
    final friendsController = _SearchRefreshFriendsController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          friendsControllerProvider.overrideWith(() => friendsController),
        ],
        child: const MaterialApp(home: FriendsDetailScreen()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'tran');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('Tran An'), findsOneWidget);
    expect(find.text('Bạn bè'), findsOneWidget);

    friendsController.bumpRevisionForTesting();
    await tester.pump();
    await tester.pump();

    expect(find.text('Tran An'), findsOneWidget);
    expect(find.text('Bạn bè'), findsNothing);
    expect(find.text('Thêm'), findsOneWidget);
  });
}
