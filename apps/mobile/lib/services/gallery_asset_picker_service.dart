import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'gallery_permission_service.dart';

typedef GalleryAssetLoader =
    Future<List<GalleryAssetPickerItem>> Function(int limit);
typedef GalleryAssetPathLoader = Future<String?> Function();

const int maxGalleryVideoDurationMs = 3000;

enum GalleryAssetMediaType { image, video }

class GalleryAssetGps {
  final double latitude;
  final double longitude;

  const GalleryAssetGps({required this.latitude, required this.longitude});

  List<double> toList() => <double>[latitude, longitude];
}

class GalleryAssetPickerItem {
  const GalleryAssetPickerItem({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.mediaType,
    required this.loadPath,
    this.durationMs,
    this.gpsCoordinates,
  });

  final String id;
  final String? title;
  final Uint8List thumbnail;
  final GalleryAssetMediaType mediaType;
  final GalleryAssetPathLoader loadPath;
  final int? durationMs;
  final GalleryAssetGps? gpsCoordinates;

  bool get isVideo => mediaType == GalleryAssetMediaType.video;
}

String galleryAssetSourceForMediaType(GalleryAssetMediaType mediaType) {
  return switch (mediaType) {
    GalleryAssetMediaType.image => 'EXIF_GALLERY',
    GalleryAssetMediaType.video => 'EXIF_GALLERY_VIDEO',
  };
}

String? galleryAssetUploadError(GalleryAssetPickerItem item) {
  if (!item.isVideo) return null;

  final durationMs = item.durationMs;
  if (durationMs == null || durationMs <= 0) {
    return 'Không đọc được thời lượng video.';
  }
  if (durationMs > maxGalleryVideoDurationMs) {
    return 'Video chỉ được tối đa 3 giây.';
  }
  if (item.gpsCoordinates == null) {
    return 'Video cần có GPS để xác thực check-in.';
  }

  return null;
}

class GalleryAssetPickerSelection {
  final String path;
  final String source;
  final GalleryAssetMediaType mediaType;
  final int? durationMs;
  final GalleryAssetGps? gpsCoordinates;

  const GalleryAssetPickerSelection({
    required this.path,
    required this.source,
    required this.mediaType,
    this.durationMs,
    this.gpsCoordinates,
  });
}

class GalleryAssetPickerService {
  const GalleryAssetPickerService({
    this.permissionService = const GalleryPermissionService(),
    GalleryAssetLoader? loadAssets,
  }) : _loadAssets = loadAssets ?? _loadRecentAssetItems;

  final GalleryPermissionService permissionService;
  final GalleryAssetLoader _loadAssets;

  Future<List<GalleryAssetPickerItem>> loadRecentImages({int limit = 60}) {
    return loadRecentMedia(limit: limit);
  }

  Future<List<GalleryAssetPickerItem>> loadRecentMedia({int limit = 60}) async {
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
    final recentMediaFilter = FilterOptionGroup(
      orders: const [OrderOption(type: OrderOptionType.createDate, asc: false)],
    );

    final paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.common,
      filterOption: recentMediaFilter,
    );
    if (paths.isEmpty) return const <GalleryAssetPickerItem>[];

    final assets = await paths.first.getAssetListRange(start: 0, end: limit);
    if (assets.isEmpty) return const <GalleryAssetPickerItem>[];

    final items = <GalleryAssetPickerItem>[];
    for (final asset in assets) {
      if (asset.type != AssetType.image && asset.type != AssetType.video) {
        continue;
      }

      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(220),
        quality: 85,
      );
      if (thumbnail == null) continue;

      final mediaType = asset.type == AssetType.video
          ? GalleryAssetMediaType.video
          : GalleryAssetMediaType.image;
      final gpsCoordinates = await _gpsForAsset(asset);

      items.add(
        GalleryAssetPickerItem(
          id: asset.id,
          title: asset.title,
          thumbnail: thumbnail,
          mediaType: mediaType,
          durationMs: mediaType == GalleryAssetMediaType.video
              ? asset.duration * 1000
              : null,
          gpsCoordinates: gpsCoordinates,
          loadPath: () async => (await asset.originFile)?.path,
        ),
      );
    }

    return items;
  }

  static Future<GalleryAssetGps?> _gpsForAsset(AssetEntity asset) async {
    final immediate = asset.latLng;
    if (immediate != null) {
      return GalleryAssetGps(
        latitude: immediate.latitude,
        longitude: immediate.longitude,
      );
    }

    final asyncValue = await asset.latlngAsync();
    if (asyncValue == null) return null;

    return GalleryAssetGps(
      latitude: asyncValue.latitude,
      longitude: asyncValue.longitude,
    );
  }
}
