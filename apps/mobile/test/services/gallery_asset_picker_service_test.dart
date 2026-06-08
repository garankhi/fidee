import 'dart:typed_data';

import 'package:fidee_mobile/services/gallery_asset_picker_service.dart';
import 'package:fidee_mobile/services/gallery_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  group('GalleryAssetPickerService', () {
    test('does not load assets without library access', () async {
      var assetLoads = 0;
      final service = GalleryAssetPickerService(
        permissionService: GalleryPermissionService(
          getPermissionState: () async => PermissionState.denied,
          requestPermission: () async => PermissionState.denied,
          presentLimited: () async {},
          openSettings: () async {},
        ),
        loadAssets: (limit) async {
          assetLoads += 1;
          return const <GalleryAssetPickerItem>[];
        },
      );

      final assets = await service.loadRecentImages();

      expect(assets, isEmpty);
      expect(assetLoads, 0);
    });

    test('loads recent assets when access is limited', () async {
      final thumbnail = Uint8List.fromList(<int>[1, 2]);
      final service = GalleryAssetPickerService(
        permissionService: GalleryPermissionService(
          getPermissionState: () async => PermissionState.limited,
          requestPermission: () async => PermissionState.denied,
          presentLimited: () async {},
          openSettings: () async {},
        ),
        loadAssets: (limit) async => <GalleryAssetPickerItem>[
          GalleryAssetPickerItem(
            id: 'asset-1',
            title: 'first.jpg',
            thumbnail: thumbnail,
            loadPath: () async => 'D:/tmp/first.jpg',
          ),
        ],
      );

      final assets = await service.loadRecentImages(limit: 10);

      expect(assets, hasLength(1));
      expect(assets.single.thumbnail, thumbnail);
      expect(await assets.single.loadPath(), 'D:/tmp/first.jpg');
    });
  });
}
