import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/camera_checkin_feed_item.dart';
import '../../services/camera_checkin_feed_service.dart';
import 'auth_providers.dart';

part 'camera_checkin_feed_provider.g.dart';

class CameraCheckinFeedState {
  final CameraFeedAudience audience;
  final List<CameraCheckinFeedItem> items;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;

  const CameraCheckinFeedState({
    required this.audience,
    this.items = const <CameraCheckinFeedItem>[],
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
  });

  CameraCheckinFeedState copyWith({
    CameraFeedAudience? audience,
    List<CameraCheckinFeedItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
  }) {
    return CameraCheckinFeedState(
      audience: audience ?? this.audience,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
CameraCheckinFeedService cameraCheckinFeedService(
  CameraCheckinFeedServiceRef ref,
) {
  final authService = ref.watch(authServiceProvider);
  return CameraCheckinFeedService(authService);
}

@riverpod
class CameraCheckinFeedController extends _$CameraCheckinFeedController {
  late CameraCheckinFeedService _service;

  @override
  CameraCheckinFeedState build() {
    _service = ref.watch(cameraCheckinFeedServiceProvider);
    Future.microtask(refresh);
    return CameraCheckinFeedState(
      audience: CameraFeedAudience.everyone(),
      isLoading: true,
    );
  }

  Future<void> selectAudience(CameraFeedAudience audience) async {
    state = CameraCheckinFeedState(audience: audience, isLoading: true);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearNextCursor: true,
      hasMore: false,
    );
    final page = await _service.fetchCheckins(audience: state.audience);
    state = state.copyWith(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      isLoading: false,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.nextCursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    final page = await _service.fetchCheckins(
      audience: state.audience,
      cursor: state.nextCursor,
    );
    state = state.copyWith(
      items: <CameraCheckinFeedItem>[...state.items, ...page.items],
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
      isLoadingMore: false,
    );
  }
}
