import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config.dart';
import '../../services/appsync_realtime_service.dart';
import 'auth_providers.dart';
import 'friends_provider.dart';

final appSyncRealtimeServiceProvider = Provider<AppSyncRealtimeService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AppSyncRealtimeService(
    getToken: authService.getToken,
    graphqlUrl: Config.appSyncGraphqlUrl,
    realtimeUrl: Config.appSyncRealtimeUrl,
    region: Config.awsRegion,
  );
});

final friendRealtimeControllerProvider = Provider<FriendRealtimeController>((
  ref,
) {
  final controller = FriendRealtimeController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

class FriendRealtimeController {
  FriendRealtimeController(this._ref);

  final Ref _ref;
  StreamSubscription<FriendRealtimeEvent>? _subscription;
  String? _connectedUserId;

  Future<void> connect() async {
    final authService = _ref.read(authServiceProvider);
    final targetUserId = await authService.getCurrentUserSub();
    if (targetUserId == null || targetUserId.isEmpty) return;
    if (_subscription != null && _connectedUserId == targetUserId) return;

    await _subscription?.cancel();
    _connectedUserId = targetUserId;
    final service = _ref.read(appSyncRealtimeServiceProvider);
    _subscription = service
        .subscribeToFriendRealtimeEvents(targetUserId: targetUserId)
        .listen(
          (_) {
            unawaited(
              _ref
                  .read(friendsControllerProvider.notifier)
                  .refreshFromRealtimeEvent(),
            );
            unawaited(
              _ref
                  .read(authControllerProvider.notifier)
                  .refreshProfileDetails(),
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('Friend realtime subscription error: $error');
          },
        );
  }

  Future<void> disconnect() async {
    _connectedUserId = null;
    await _subscription?.cancel();
    _subscription = null;
    await _ref.read(appSyncRealtimeServiceProvider).disconnect();
  }

  void dispose() {
    _connectedUserId = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
