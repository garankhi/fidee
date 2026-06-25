import 'dart:async';

import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/features/auth/friends_provider.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/friend_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(isTestMode: true);

  @override
  Future<String?> getCurrentUserSub() async => 'current-user';
}

class _QueuedFriendService extends FriendService {
  _QueuedFriendService() : super(_FakeAuthService());

  final firstRequests = Completer<List<FriendProfile>>();
  int requestFetchCount = 0;

  @override
  Future<List<FriendProfile>> fetchFriends() async => const <FriendProfile>[];

  @override
  Future<List<FriendProfile>> fetchFriendRequests() {
    requestFetchCount += 1;
    if (requestFetchCount == 1) {
      return firstRequests.future;
    }
    return Future.value(const <FriendProfile>[
      FriendProfile(id: 'user-1', name: 'Nguyen Minh', handle: 'user23'),
    ]);
  }

  @override
  Future<List<FriendProfile>> fetchSentFriendRequests() async =>
      const <FriendProfile>[];
}

void main() {
  test(
    'queues realtime refresh when an existing friends load is in progress',
    () async {
      final service = _QueuedFriendService();
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_FakeAuthService()),
          friendServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(friendsControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(service.requestFetchCount, 1);

      await controller.refreshFromRealtimeEvent();
      service.firstRequests.complete(const <FriendProfile>[]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(service.requestFetchCount, 2);
      expect(
        container.read(friendsControllerProvider).requests.single.id,
        'user-1',
      );
    },
  );
}
