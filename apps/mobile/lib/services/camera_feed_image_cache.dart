import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/camera_checkin_feed_item.dart';

class CameraFeedImageCacheManager {
  static const key = 'cameraFeedImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 120,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

String cameraFeedImageCacheKey(CameraCheckinFeedItem item) {
  final mediaId = item.mediaId?.trim() ?? '';
  return mediaId.isNotEmpty ? mediaId : item.imageUrl;
}

List<CameraCheckinFeedItem> nextCameraFeedDiskPrefetchItems({
  required List<CameraCheckinFeedItem> items,
  required CameraCheckinFeedItem? activeItem,
  int limit = 3,
}) {
  return _nextCameraFeedItems(items: items, activeItem: activeItem, limit: limit);
}

List<CameraCheckinFeedItem> nextCameraFeedMemoryPrecacheItems({
  required List<CameraCheckinFeedItem> items,
  required CameraCheckinFeedItem? activeItem,
  int limit = 1,
}) {
  return _nextCameraFeedItems(items: items, activeItem: activeItem, limit: limit);
}

List<CameraCheckinFeedItem> _nextCameraFeedItems({
  required List<CameraCheckinFeedItem> items,
  required CameraCheckinFeedItem? activeItem,
  required int limit,
}) {
  if (items.isEmpty || limit <= 0) return const <CameraCheckinFeedItem>[];

  final startIndex = activeItem == null
      ? 0
      : items.indexWhere((item) => item.id == activeItem.id) + 1;

  if (startIndex <= 0 && activeItem != null) {
    return const <CameraCheckinFeedItem>[];
  }
  if (startIndex >= items.length) return const <CameraCheckinFeedItem>[];

  return items.skip(startIndex).take(limit).toList(growable: false);
}
