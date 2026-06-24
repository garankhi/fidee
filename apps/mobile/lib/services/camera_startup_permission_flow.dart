import 'dart:typed_data';

import 'package:permission_handler/permission_handler.dart';

import 'gallery_permission_service.dart';
import 'gallery_preview_service.dart';

typedef CameraPermissionStatusGetter = Future<PermissionStatus> Function();
typedef CameraPermissionRequester = Future<PermissionStatus> Function();
typedef GalleryPreviewLoader = Future<GalleryPreviewResult> Function();

class CameraStartupPermissionResult {
  const CameraStartupPermissionResult({
    required this.cameraStatus,
    required this.galleryPreview,
  });

  final PermissionStatus cameraStatus;
  final GalleryPreviewResult galleryPreview;

  bool get cameraGranted => cameraStatus.isGranted || cameraStatus.isLimited;

  List<Uint8List> get galleryThumbnails => galleryPreview.thumbnails;
}

class CameraStartupPermissionFlow {
  const CameraStartupPermissionFlow({
    required this.getCameraStatus,
    required this.requestCameraPermission,
    required this.loadGalleryPreview,
  });

  factory CameraStartupPermissionFlow.live({
    GalleryPreviewService galleryPreviewService = const GalleryPreviewService(),
  }) {
    return CameraStartupPermissionFlow(
      getCameraStatus: () => Permission.camera.status,
      requestCameraPermission: () => Permission.camera.request(),
      loadGalleryPreview: galleryPreviewService.loadRecentThumbnails,
    );
  }

  final CameraPermissionStatusGetter getCameraStatus;
  final CameraPermissionRequester requestCameraPermission;
  final GalleryPreviewLoader loadGalleryPreview;

  Future<CameraStartupPermissionResult> resolve() async {
    var cameraStatus = await getCameraStatus();

    if (cameraStatus.isDenied) {
      cameraStatus = await requestCameraPermission();
    }

    if (!cameraStatus.isGranted && !cameraStatus.isLimited) {
      return CameraStartupPermissionResult(
        cameraStatus: cameraStatus,
        galleryPreview: const GalleryPreviewResult(
          permissionStatus: GalleryPermissionStatus.denied,
          thumbnails: <Uint8List>[],
        ),
      );
    }

    final galleryPreview = await loadGalleryPreview();
    return CameraStartupPermissionResult(
      cameraStatus: cameraStatus,
      galleryPreview: galleryPreview,
    );
  }
}
