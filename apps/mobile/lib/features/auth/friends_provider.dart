import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../services/friend_service.dart';
import 'auth_providers.dart';

part 'friends_provider.g.dart';

class FriendsState {
  final List<FriendProfile> friends;
  final List<FriendProfile> requests;
  final List<FriendProfile> sentRequests;
  final bool isLoading;
  final int revision;

  const FriendsState({
    this.friends = const [],
    this.requests = const [],
    this.sentRequests = const [],
    this.isLoading = false,
    this.revision = 0,
  });

  FriendsState copyWith({
    List<FriendProfile>? friends,
    List<FriendProfile>? requests,
    List<FriendProfile>? sentRequests,
    bool? isLoading,
    int? revision,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      requests: requests ?? this.requests,
      sentRequests: sentRequests ?? this.sentRequests,
      isLoading: isLoading ?? this.isLoading,
      revision: revision ?? this.revision,
    );
  }

  int get friendCount => friends.length;
  int get requestCount => requests.length;
  int get sentRequestCount => sentRequests.length;
  bool get hasFriendRequests => requests.isNotEmpty;
  bool get hasSentFriendRequests => sentRequests.isNotEmpty;
  bool get isInitialLoading =>
      isLoading && friends.isEmpty && requests.isEmpty && sentRequests.isEmpty;
}

@Riverpod(keepAlive: true)
FriendService friendService(FriendServiceRef ref) {
  final authService = ref.watch(authServiceProvider);
  return FriendService(authService);
}

@Riverpod(keepAlive: true)
class FriendsController extends _$FriendsController {
  late FriendService _service;
  bool _isLoadingNow = false;
  bool _shouldReloadAfterCurrentLoad = false;

  @override
  FriendsState build() {
    _service = ref.watch(friendServiceProvider);
    // Fetch background data without blocking initial frame.
    Future.microtask(() => load());
    return const FriendsState(isLoading: true);
  }

  Future<void> load({bool silent = false}) async {
    if (_isLoadingNow) {
      _shouldReloadAfterCurrentLoad = true;
      return;
    }

    var nextLoadIsSilent = silent;
    do {
      _shouldReloadAfterCurrentLoad = false;
      _isLoadingNow = true;
      try {
        if (!nextLoadIsSilent) {
          state = state.copyWith(isLoading: true);
        }
        final results = await Future.wait<List<FriendProfile>>([
          _service.fetchFriends(),
          _service.fetchFriendRequests(),
          _service.fetchSentFriendRequests(),
        ]);

        state = FriendsState(
          friends: results[0],
          requests: results[1],
          sentRequests: results[2],
          isLoading: false,
          revision: state.revision + 1,
        );
      } finally {
        _isLoadingNow = false;
      }
      nextLoadIsSilent = true;
    } while (_shouldReloadAfterCurrentLoad);
  }

  Future<void> refreshFromRealtimeEvent() => load(silent: true);

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
      unawaited(load(silent: true));
    }
    return success;
  }

  Future<bool> cancelFriendRequest(String userId) async {
    final success = await _service.cancelFriendRequest(userId);
    if (success) {
      state = state.copyWith(
        sentRequests: state.sentRequests
            .where((request) => request.id != userId)
            .toList(growable: false),
      );
      unawaited(load(silent: true));
    }
    return success;
  }
}
