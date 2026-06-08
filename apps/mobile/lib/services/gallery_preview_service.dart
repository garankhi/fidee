import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_permission_service.dart';

typedef GalleryThumbnailLoader = Future<List<Uint8List>> Function(int limit);

class GalleryPreviewResult {
  const GalleryPreviewResult({
    required this.permissionStatus,
    required this.thumbnails,
  });

  final GalleryPermissionStatus permissionStatus;
  final List<Uint8List> thumbnails;

  bool get hasLibraryAccess => permissionStatus.hasAccess;
}

class GalleryPreviewService {
  const GalleryPreviewService({
    this.permissionService = const GalleryPermissionService(),
    GalleryThumbnailLoader? loadThumbnails,
  }) : _loadThumbnails = loadThumbnails ?? _loadRecentThumbnailBytes;

  final GalleryPermissionService permissionService;
  final GalleryThumbnailLoader _loadThumbnails;

  Future<GalleryPreviewResult> loadRecentThumbnails({int limit = 2}) async {
    var permissionStatus = GalleryPermissionStatus.notDetermined;

    try {
      permissionStatus = await permissionService.currentStatus();

      if (permissionStatus == GalleryPermissionStatus.notDetermined) {
        permissionStatus = await permissionService.requestAccess();
      }

      if (limit <= 0 || !permissionStatus.hasAccess) {
        return GalleryPreviewResult(
          permissionStatus: permissionStatus,
          thumbnails: const <Uint8List>[],
        );
      }

      final thumbnails = await _loadThumbnails(limit);
      return GalleryPreviewResult(
        permissionStatus: permissionStatus,
        thumbnails: thumbnails,
      );
    } catch (error, stackTrace) {
      debugPrint('Gallery preview load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return GalleryPreviewResult(
        permissionStatus: permissionStatus,
        thumbnails: const <Uint8List>[],
      );
    }
  }

  static Future<List<Uint8List>> _loadRecentThumbnailBytes(int limit) async {
    final recentImagesFilter = FilterOptionGroup(
      orders: const [
        OrderOption(type: OrderOptionType.createDate, asc: false),
      ],
    );

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: recentImagesFilter,
    );
    if (paths.isEmpty) return const <Uint8List>[];

    final assets = await paths.first.getAssetListRange(start: 0, end: limit);
    if (assets.isEmpty) return const <Uint8List>[];

    final thumbnails = <Uint8List>[];
    for (final asset in assets) {
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(128),
        quality: 85,
      );
      if (bytes != null) thumbnails.add(bytes);
    }

    return thumbnails;
  }
}
