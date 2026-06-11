import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/features/auth/friends_provider.dart';
import 'package:fidee_mobile/screens/friends_detail_screen.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/friend_service.dart';
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

  @override
  FriendsState build() {
    return const FriendsState(
      requests: [FriendProfile(id: 'request-1', name: 'Lan Tran', handle: 'lan')],
    );
  }

  @override
  Future<bool> accept(String userId) async {
    acceptedUserId = userId;
    return true;
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

    await tester.tap(find.byKey(const ValueKey('friend-request-accept-request-1')));
    await tester.pump();

    expect(friendsController.acceptedUserId, 'request-1');
    expect(find.text('Đã chấp nhận lời mời'), findsOneWidget);
  });
}
