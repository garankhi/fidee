import 'dart:typed_data';

import 'package:fidey_mobile/services/camera_startup_permission_flow.dart';
import 'package:fidey_mobile/services/gallery_permission_service.dart';
import 'package:fidey_mobile/services/gallery_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('CameraStartupPermissionFlow', () {
    test('requests camera before loading gallery preview', () async {
      final calls = <String>[];
      final thumbnails = <Uint8List>[
        Uint8List.fromList(<int>[1, 2, 3]),
      ];

      final flow = CameraStartupPermissionFlow(
        getCameraStatus: () async {
          calls.add('camera-status');
          return PermissionStatus.denied;
        },
        requestCameraPermission: () async {
          calls.add('camera-request');
          return PermissionStatus.granted;
        },
        loadGalleryPreview: () async {
          calls.add('gallery-preview');
          return GalleryPreviewResult(
            permissionStatus: GalleryPermissionStatus.full,
            thumbnails: thumbnails,
          );
        },
      );

      final result = await flow.resolve();

      expect(result.cameraGranted, isTrue);
      expect(
        result.galleryPreview.permissionStatus,
        GalleryPermissionStatus.full,
      );
      expect(result.galleryPreview.thumbnails, same(thumbnails));
      expect(calls, <String>[
        'camera-status',
        'camera-request',
        'gallery-preview',
      ]);
    });

    test(
      'does not load gallery preview when camera permission is denied',
      () async {
        final calls = <String>[];

        final flow = CameraStartupPermissionFlow(
          getCameraStatus: () async {
            calls.add('camera-status');
            return PermissionStatus.denied;
          },
          requestCameraPermission: () async {
            calls.add('camera-request');
            return PermissionStatus.denied;
          },
          loadGalleryPreview: () async {
            calls.add('gallery-preview');
            return const GalleryPreviewResult(
              permissionStatus: GalleryPermissionStatus.denied,
              thumbnails: <Uint8List>[],
            );
          },
        );

        final result = await flow.resolve();

        expect(result.cameraGranted, isFalse);
        expect(result.cameraStatus, PermissionStatus.denied);
        expect(
          result.galleryPreview.permissionStatus,
          GalleryPermissionStatus.denied,
        );
        expect(result.galleryPreview.thumbnails, isEmpty);
        expect(calls, <String>['camera-status', 'camera-request']);
      },
    );

    test(
      'loads gallery preview immediately when camera permission is already granted',
      () async {
        final calls = <String>[];
        final thumbnails = <Uint8List>[
          Uint8List.fromList(<int>[9]),
        ];

        final flow = CameraStartupPermissionFlow(
          getCameraStatus: () async {
            calls.add('camera-status');
            return PermissionStatus.granted;
          },
          requestCameraPermission: () async {
            calls.add('camera-request');
            return PermissionStatus.granted;
          },
          loadGalleryPreview: () async {
            calls.add('gallery-preview');
            return GalleryPreviewResult(
              permissionStatus: GalleryPermissionStatus.limited,
              thumbnails: thumbnails,
            );
          },
        );

        final result = await flow.resolve();

        expect(result.cameraGranted, isTrue);
        expect(
          result.galleryPreview.permissionStatus,
          GalleryPermissionStatus.limited,
        );
        expect(result.galleryPreview.thumbnails, same(thumbnails));
        expect(calls, <String>['camera-status', 'gallery-preview']);
      },
    );
  });
}
