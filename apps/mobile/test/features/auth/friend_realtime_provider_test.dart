import 'dart:async';

import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/features/auth/friend_realtime_provider.dart';
import 'package:fidee_mobile/features/auth/friends_provider.dart';
import 'package:fidee_mobile/services/appsync_realtime_service.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(isTestMode: true);

  @override
  Future<String?> getToken() async => 'token-123';

  @override
  Future<String?> getCurrentUserSub() async => 'user-sub-1';
}

class _FakeRealtimeService extends AppSyncRealtimeService {
  _FakeRealtimeService()
      : super(
          getToken: () async => 'token-123',
          graphqlUrl: 'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
          realtimeUrl: 'wss://abc123.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql',
          region: 'ap-southeast-1',
        );

  final controller = StreamController<FriendRequestRealtimeEvent>.broadcast();
  String? subscribedUserId;

  @override
  Stream<FriendRequestRealtimeEvent> subscribeToFriendRequests({required String targetUserId}) {
    subscribedUserId = targetUserId;
    return controller.stream;
  }
}

class _RefreshCountingFriendsController extends FriendsController {
  int refreshCount = 0;

  @override
  FriendsState build() => const FriendsState();

  @override
  Future<void> refreshFromRealtimeEvent() async {
    refreshCount += 1;
  }
}

void main() {
  test('refreshes friends when realtime stream emits an event', () async {
    final realtimeService = _FakeRealtimeService();
    final friendsController = _RefreshCountingFriendsController();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        appSyncRealtimeServiceProvider.overrideWithValue(realtimeService),
        friendsControllerProvider.overrideWith(() => friendsController),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(realtimeService.controller.close);

    await container.read(friendRealtimeControllerProvider).connect();
    realtimeService.controller.add(
      FriendRequestRealtimeEvent(
        eventId: 'friend_request#user-1#user-sub-1',
        targetUserId: 'user-sub-1',
        requesterId: 'user-1',
        requesterName: 'Minh Nguyen',
        requesterUsername: 'minh',
        requesterAvatarUrl: '',
        createdAt: DateTime.parse('2026-06-11T03:00:00.000Z'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(realtimeService.subscribedUserId, 'user-sub-1');
    expect(friendsController.refreshCount, 1);
  });
}
