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
        graphqlUrl:
            'https://abc123.appsync-api.ap-southeast-1.amazonaws.com/graphql',
        realtimeUrl:
            'wss://abc123.appsync-realtime-api.ap-southeast-1.amazonaws.com/graphql',
        region: 'ap-southeast-1',
      );

  final controller = StreamController<FriendRealtimeEvent>.broadcast();
  String? subscribedUserId;

  @override
  Stream<FriendRealtimeEvent> subscribeToFriendRealtimeEvents({
    required String targetUserId,
  }) {
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

class _RefreshCountingAuthController extends AuthController {
  int refreshCount = 0;

  @override
  Future<AuthUiState> build() async {
    return const AuthUiState(authState: AuthState.authenticated);
  }

  @override
  Future<void> refreshProfileDetails() async {
    refreshCount += 1;
  }
}

void main() {
  test(
    'refreshes friends and profile when realtime stream emits an event',
    () async {
      final realtimeService = _FakeRealtimeService();
      final friendsController = _RefreshCountingFriendsController();
      final authController = _RefreshCountingAuthController();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          authControllerProvider.overrideWith(() => authController),
          appSyncRealtimeServiceProvider.overrideWithValue(realtimeService),
          friendsControllerProvider.overrideWith(() => friendsController),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(realtimeService.controller.close);

      await container.read(friendRealtimeControllerProvider).connect();
      realtimeService.controller.add(
        FriendRealtimeEvent(
          eventId: 'friendship_removed#user-sub-1#user-2',
          type: 'FRIENDSHIP_REMOVED',
          targetUserId: 'user-sub-1',
          actorUserId: 'user-2',
          relatedUserId: 'user-2',
          actorName: 'Tran An',
          actorUsername: 'tran',
          actorAvatarUrl: '',
          createdAt: DateTime.parse('2026-06-12T03:00:00.000Z'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(realtimeService.subscribedUserId, 'user-sub-1');
      expect(friendsController.refreshCount, 1);
      expect(authController.refreshCount, 1);
    },
  );
}
