import 'package:fidee_mobile/features/auth/friends_provider.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/friend_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFriendService extends FriendService {
  _FakeFriendService() : super(AuthService(isTestMode: true));

  List<FriendProfile> friends = const <FriendProfile>[];
  List<FriendProfile> requests = const <FriendProfile>[];

  @override
  Future<List<FriendProfile>> fetchFriends() async => friends;

  @override
  Future<List<FriendProfile>> fetchFriendRequests() async => requests;
}

void main() {
  test('FriendsState exposes request counters and initial loading helper', () {
    const state = FriendsState(
      friends: [FriendProfile(id: 'friend-1', name: 'Minh', handle: 'minh')],
      requests: [FriendProfile(id: 'request-1', name: 'Lan', handle: 'lan')],
      isLoading: true,
    );

    expect(state.friendCount, 1);
    expect(state.requestCount, 1);
    expect(state.hasFriendRequests, isTrue);
    expect(state.isInitialLoading, isFalse);
    expect(const FriendsState(isLoading: true).isInitialLoading, isTrue);
  });

  test('refreshFromRealtimeEvent reloads without setting loading state', () async {
    final service = _FakeFriendService()
      ..friends = const [FriendProfile(id: 'friend-1', name: 'Minh', handle: 'minh')]
      ..requests = const [FriendProfile(id: 'request-1', name: 'Lan', handle: 'lan')];
    final container = ProviderContainer(
      overrides: [friendServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final controller = container.read(friendsControllerProvider.notifier);
    await controller.refreshFromRealtimeEvent();

    final state = container.read(friendsControllerProvider);
    expect(state.isLoading, isFalse);
    expect(state.friends.single.id, 'friend-1');
    expect(state.requests.single.id, 'request-1');
  });
}
