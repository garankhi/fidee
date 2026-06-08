import 'package:fidee_mobile/services/gallery_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  group('GalleryPermissionService', () {
    test('reports full access when photo manager is authorized', () async {
      final service = GalleryPermissionService(
        getPermissionState: () async => PermissionState.authorized,
        requestPermission: () async => PermissionState.denied,
        presentLimited: () async {},
        openSettings: () async {},
      );

      final status = await service.currentStatus();

      expect(status, GalleryPermissionStatus.full);
      expect(status.hasAccess, isTrue);
    });

    test('reports selected access when photo manager is limited', () async {
      final service = GalleryPermissionService(
        getPermissionState: () async => PermissionState.limited,
        requestPermission: () async => PermissionState.denied,
        presentLimited: () async {},
        openSettings: () async {},
      );

      final status = await service.currentStatus();

      expect(status, GalleryPermissionStatus.limited);
      expect(status.hasAccess, isTrue);
    });

    test('requests library permission and maps denial', () async {
      var requestCount = 0;
      final service = GalleryPermissionService(
        getPermissionState: () async => PermissionState.notDetermined,
        requestPermission: () async {
          requestCount += 1;
          return PermissionState.denied;
        },
        presentLimited: () async {},
        openSettings: () async {},
      );

      final status = await service.requestAccess();

      expect(status, GalleryPermissionStatus.denied);
      expect(status.hasAccess, isFalse);
      expect(requestCount, 1);
    });

    test('opens limited picker then returns refreshed status', () async {
      var presented = false;
      var state = PermissionState.limited;
      final service = GalleryPermissionService(
        getPermissionState: () async => state,
        requestPermission: () async => PermissionState.denied,
        presentLimited: () async {
          presented = true;
          state = PermissionState.authorized;
        },
        openSettings: () async {},
      );

      final status = await service.presentLimitedPicker();

      expect(presented, isTrue);
      expect(status, GalleryPermissionStatus.full);
    });

    test('opens app settings for full access changes', () async {
      var opened = false;
      final service = GalleryPermissionService(
        getPermissionState: () async => PermissionState.denied,
        requestPermission: () async => PermissionState.denied,
        presentLimited: () async {},
        openSettings: () async {
          opened = true;
        },
      );

      await service.openPhotoSettings();

      expect(opened, isTrue);
    });
  });
}
