import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/friend_service.dart';
import 'auth_providers.dart';

part 'friends_provider.g.dart';

class FriendsState {
  final List<FriendProfile> friends;
  final List<FriendProfile> requests;
  final bool isLoading;

  const FriendsState({
    this.friends = const [],
    this.requests = const [],
    this.isLoading = false,
  });

  FriendsState copyWith({
    List<FriendProfile>? friends,
    List<FriendProfile>? requests,
    bool? isLoading,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@Riverpod(keepAlive: true)
FriendService friendService(FriendServiceRef ref) {
  final authService = ref.watch(authServiceProvider);
  return FriendService(authService);
}

@Riverpod(keepAlive: true)
class FriendsController extends _$FriendsController {
  late FriendService _service;

  @override
  FriendsState build() {
    _service = ref.watch(friendServiceProvider);
    // Fetch background data without blocking initial frame.
    Future.microtask(() => load());
    return const FriendsState(isLoading: true);
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final friendsList = await _service.fetchFriends();
    final requestsList = await _service.fetchFriendRequests();

    state = FriendsState(
      friends: friendsList,
      requests: requestsList,
      isLoading: false,
    );
  }

  Future<List<FriendSearchResult>> searchUsers(String username) {
    return _service.searchUsersByUsername(username);
  }

  Future<bool> accept(String userId) async {
    final success = await _service.acceptFriend(userId);
    if (success) {
      await load();
      final authService = ref.read(authServiceProvider);
      await authService.fetchProfileDetails();
    }
    return success;
  }

  Future<bool> decline(String userId) async {
    final success = await _service.declineFriend(userId);
    if (success) {
      await load();
    }
    return success;
  }

  Future<bool> unfriend(String userId) async {
    final success = await _service.unfriend(userId);
    if (success) {
      await load();
      final authService = ref.read(authServiceProvider);
      await authService.fetchProfileDetails();
    }
    return success;
  }

  Future<bool> hide(String userId) async {
    final success = await _service.hideFriend(userId);
    if (success) {
      await load();
    }
    return success;
  }

  Future<bool> block(String userId) async {
    final success = await _service.blockFriend(userId);
    if (success) {
      await load();
      final authService = ref.read(authServiceProvider);
      await authService.fetchProfileDetails();
    }
    return success;
  }

  Future<bool> addFriend(String userId) async {
    final success = await _service.sendFriendRequest(userId);
    if (success) {
      await load();
    }
    return success;
  }
}