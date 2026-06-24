import 'package:photo_manager/photo_manager.dart';

typedef GalleryPermissionStateGetter = Future<PermissionState> Function();
typedef GalleryPermissionRequester = Future<PermissionState> Function();
typedef GalleryLimitedPresenter = Future<void> Function();
typedef GallerySettingsOpener = Future<void> Function();

enum GalleryPermissionStatus {
  notDetermined,
  denied,
  limited,
  full;

  bool get hasAccess => this == limited || this == full;
}

class GalleryPermissionService {
  const GalleryPermissionService({
    GalleryPermissionStateGetter? getPermissionState,
    GalleryPermissionRequester? requestPermission,
    GalleryLimitedPresenter? presentLimited,
    GallerySettingsOpener? openSettings,
  }) : _getPermissionState = getPermissionState ?? _liveGetPermissionState,
       _requestPermission = requestPermission ?? _liveRequestPermission,
       _presentLimited = presentLimited ?? _livePresentLimited,
       _openSettings = openSettings ?? PhotoManager.openSetting;

  static const permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  final GalleryPermissionStateGetter _getPermissionState;
  final GalleryPermissionRequester _requestPermission;
  final GalleryLimitedPresenter _presentLimited;
  final GallerySettingsOpener _openSettings;

  Future<GalleryPermissionStatus> currentStatus() async {
    final state = await _getPermissionState();
    return GalleryPermissionStatusMapper.fromPhotoManager(state);
  }

  Future<GalleryPermissionStatus> requestAccess() async {
    final state = await _requestPermission();
    return GalleryPermissionStatusMapper.fromPhotoManager(state);
  }

  Future<GalleryPermissionStatus> presentLimitedPicker() async {
    await _presentLimited();
    return currentStatus();
  }

  Future<void> openPhotoSettings() => _openSettings();

  static Future<PermissionState> _liveGetPermissionState() {
    return PhotoManager.getPermissionState(requestOption: permissionOption);
  }

  static Future<PermissionState> _liveRequestPermission() {
    return PhotoManager.requestPermissionExtend(
      requestOption: permissionOption,
    );
  }

  static Future<void> _livePresentLimited() {
    return PhotoManager.presentLimited(type: RequestType.image);
  }
}

extension GalleryPermissionStatusMapper on GalleryPermissionStatus {
  static GalleryPermissionStatus fromPhotoManager(PermissionState state) {
    return switch (state) {
      PermissionState.notDetermined => GalleryPermissionStatus.notDetermined,
      PermissionState.authorized => GalleryPermissionStatus.full,
      PermissionState.limited => GalleryPermissionStatus.limited,
      PermissionState.denied ||
      PermissionState.restricted => GalleryPermissionStatus.denied,
    };
  }
}
