import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/features/auth/friends_provider.dart';
import 'package:fidey_mobile/screens/profile_screen.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _HydratedAuthController extends AuthController {
  @override
  Future<AuthUiState> build() async {
    return const AuthUiState(
      authState: AuthState.authenticated,
      tier: UserTier.pro,
      firstName: 'Nguyen',
      lastName: 'Minh',
      preferredUsername: 'minh.nguyen',
      avatarUrl: null,
      since: '2026',
    );
  }
}

class _EmptyFriendsController extends FriendsController {
  @override
  FriendsState build() => const FriendsState();
}

class _PendingRequestFriendsController extends FriendsController {
  @override
  FriendsState build() => const FriendsState(
    requests: [FriendProfile(id: 'user-2', name: 'Tran An', handle: 'tran.an')],
  );
}

class _MutableFriendsController extends FriendsController {
  @override
  FriendsState build() {
    return const FriendsState(
      friends: [
        FriendProfile(id: 'user-2', name: 'Tran An', handle: 'tran.an'),
      ],
    );
  }

  void setStateForTesting(FriendsState nextState) {
    state = nextState;
  }
}

void main() {
  testWidgets('renders hydrated auth profile immediately', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HydratedAuthController.new),
          friendsControllerProvider.overrideWith(_EmptyFriendsController.new),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Nguyen Minh'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('@minh.nguyen · SINCE 2026'), findsOneWidget);
    expect(find.text('Fidey User'), findsNothing);
    expect(find.text('@user · SINCE 2026'), findsNothing);
  });

  testWidgets('shows pending friend request banner on profile', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HydratedAuthController.new),
          friendsControllerProvider.overrideWith(
            _PendingRequestFriendsController.new,
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Bạn có 1 lời mời kết bạn'), findsOneWidget);
  });

  testWidgets('updates friend count and list when friends state changes', (
    tester,
  ) async {
    final friendsController = _MutableFriendsController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_HydratedAuthController.new),
          friendsControllerProvider.overrideWith(() => friendsController),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Friends (1)'), findsOneWidget);
    expect(find.text('Tran An'), findsOneWidget);

    friendsController.setStateForTesting(const FriendsState(friends: []));
    await tester.pump();

    expect(find.text('Friends (0)'), findsOneWidget);
    expect(find.text('Tran An'), findsNothing);
    expect(find.text('Chưa có bạn bè. Hãy kết nối thêm!'), findsOneWidget);
  });
}
