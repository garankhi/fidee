import 'dart:typed_data';

import 'package:fidee_mobile/services/gallery_permission_service.dart';
import 'package:fidee_mobile/services/gallery_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  group('GalleryPreviewResult', () {
    test('full access with no thumbnails still records full permission', () {
      const result = GalleryPreviewResult(
        permissionStatus: GalleryPermissionStatus.full,
        thumbnails: <Uint8List>[],
      );

      expect(result.hasLibraryAccess, isTrue);
      expect(result.permissionStatus, GalleryPermissionStatus.full);
    });

    test('denied access has no library access', () {
      const result = GalleryPreviewResult(
        permissionStatus: GalleryPermissionStatus.denied,
        thumbnails: <Uint8List>[],
      );

      expect(result.hasLibraryAccess, isFalse);
    });
  });

  group('GalleryPreviewService', () {
    test('does not load thumbnails when gallery access is denied', () async {
      var thumbnailLoads = 0;
      final service = GalleryPreviewService(
        permissionService: GalleryPermissionService(
          getPermissionState: () async => PermissionState.denied,
          requestPermission: () async => PermissionState.authorized,
          presentLimited: () async {},
          openSettings: () async {},
        ),
        loadThumbnails: (limit) async {
          thumbnailLoads += 1;
          return <Uint8List>[Uint8List.fromList(<int>[1])];
        },
      );

      final result = await service.loadRecentThumbnails();

      expect(result.permissionStatus, GalleryPermissionStatus.denied);
      expect(result.thumbnails, isEmpty);
      expect(thumbnailLoads, 0);
    });

    test('requests access before loading thumbnails when not determined', () async {
      var requests = 0;
      final expectedThumbnail = Uint8List.fromList(<int>[7]);
      final service = GalleryPreviewService(
        permissionService: GalleryPermissionService(
          getPermissionState: () async => PermissionState.notDetermined,
          requestPermission: () async {
            requests += 1;
            return PermissionState.limited;
          },
          presentLimited: () async {},
          openSettings: () async {},
        ),
        loadThumbnails: (limit) async => <Uint8List>[expectedThumbnail],
      );

      final result = await service.loadRecentThumbnails();

      expect(requests, 1);
      expect(result.permissionStatus, GalleryPermissionStatus.limited);
      expect(result.thumbnails, <Uint8List>[expectedThumbnail]);
    });

    test('returns permission status when limit is zero', () async {
      final service = GalleryPreviewService(
        permissionService: GalleryPermissionService(
          getPermissionState: () async => PermissionState.authorized,
          requestPermission: () async => PermissionState.denied,
          presentLimited: () async {},
          openSettings: () async {},
        ),
        loadThumbnails: (limit) async => <Uint8List>[Uint8List.fromList(<int>[1])],
      );

      final result = await service.loadRecentThumbnails(limit: 0);

      expect(result.permissionStatus, GalleryPermissionStatus.full);
      expect(result.thumbnails, isEmpty);
    });
  });
}
