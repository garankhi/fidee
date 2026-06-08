import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryPreviewService {
  const GalleryPreviewService();

  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  Future<List<Uint8List>> loadRecentThumbnails({int limit = 2}) async {
    if (limit <= 0) return const <Uint8List>[];

    try {
      var permission = await PhotoManager.getPermissionState(
        requestOption: _permissionOption,
      );

      if (permission == PermissionState.notDetermined) {
        permission = await PhotoManager.requestPermissionExtend(
          requestOption: _permissionOption,
        );
      }

      if (!permission.hasAccess) return const <Uint8List>[];

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
    } catch (error, stackTrace) {
      debugPrint('Gallery preview load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <Uint8List>[];
    }
  }
}
