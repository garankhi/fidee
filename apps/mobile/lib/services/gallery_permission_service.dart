import 'package:photo_manager/photo_manager.dart' as photo_manager;

typedef GalleryPermissionStateGetter = Future<photo_manager.PermissionState> Function();
typedef GalleryPermissionRequester = Future<photo_manager.PermissionState> Function();
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
       _openSettings = openSettings ?? photo_manager.PhotoManager.openSetting;

  static const permissionOption = photo_manager.PermissionRequestOption(
    androidPermission: photo_manager.AndroidPermission(
      type: photo_manager.RequestType.image,
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

  static Future<photo_manager.PermissionState> _liveGetPermissionState() {
    return photo_manager.PhotoManager.getPermissionState(requestOption: permissionOption);
  }

  static Future<photo_manager.PermissionState> _liveRequestPermission() {
    return photo_manager.PhotoManager.requestPermissionExtend(requestOption: permissionOption);
  }

  static Future<void> _livePresentLimited() {
    return photo_manager.PhotoManager.presentLimited(type: photo_manager.RequestType.image);
  }
}

extension GalleryPermissionStatusMapper on GalleryPermissionStatus {
  static GalleryPermissionStatus fromPhotoManager(photo_manager.PermissionState state) {
    return switch (state) {
      photo_manager.PermissionState.notDetermined => GalleryPermissionStatus.notDetermined,
      photo_manager.PermissionState.authorized => GalleryPermissionStatus.full,
      photo_manager.PermissionState.limited => GalleryPermissionStatus.limited,
      photo_manager.PermissionState.denied || photo_manager.PermissionState.restricted =>
        GalleryPermissionStatus.denied,
    };
  }
}
