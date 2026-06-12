import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_permission_service.dart';

typedef GalleryAssetLoader =
    Future<List<GalleryAssetPickerItem>> Function(int limit);
typedef GalleryAssetPathLoader = Future<String?> Function();

class GalleryAssetPickerItem {
  const GalleryAssetPickerItem({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.loadPath,
  });

  final String id;
  final String? title;
  final Uint8List thumbnail;
  final GalleryAssetPathLoader loadPath;
}

class GalleryAssetPickerService {
  const GalleryAssetPickerService({
    this.permissionService = const GalleryPermissionService(),
    GalleryAssetLoader? loadAssets,
  }) : _loadAssets = loadAssets ?? _loadRecentAssetItems;

  final GalleryPermissionService permissionService;
  final GalleryAssetLoader _loadAssets;

  Future<List<GalleryAssetPickerItem>> loadRecentImages({
    int limit = 60,
  }) async {
    if (limit <= 0) return const <GalleryAssetPickerItem>[];

    try {
      final status = await permissionService.currentStatus();
      if (!status.hasAccess) return const <GalleryAssetPickerItem>[];

      return _loadAssets(limit);
    } catch (error, stackTrace) {
      debugPrint('Gallery asset picker load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <GalleryAssetPickerItem>[];
    }
  }

  static Future<List<GalleryAssetPickerItem>> _loadRecentAssetItems(
    int limit,
  ) async {
    final recentImagesFilter = FilterOptionGroup(
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: recentImagesFilter,
    );
    if (paths.isEmpty) return const <GalleryAssetPickerItem>[];

    final assets = await paths.first.getAssetListRange(start: 0, end: limit);
    if (assets.isEmpty) return const <GalleryAssetPickerItem>[];

    final items = <GalleryAssetPickerItem>[];
    for (final asset in assets) {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(220),
        quality: 85,
      );
      if (thumbnail == null) continue;

      items.add(
        GalleryAssetPickerItem(
          id: asset.id,
          title: asset.title,
          thumbnail: thumbnail,
          loadPath: () async => (await asset.originFile)?.path,
        ),
      );
    }

    return items;
  }
}
