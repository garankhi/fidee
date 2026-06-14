import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationStatus { loading, granted, denied, deniedForever, serviceDisabled }

typedef LocationServiceEnabledReader = Future<bool> Function();
typedef LocationPermissionReader = Future<PermissionStatus> Function();
typedef LocationPermissionRequester = Future<PermissionStatus> Function();
typedef CurrentPositionReader =
    Future<Position> Function({LocationSettings? locationSettings});
typedef PositionStreamReader =
    Stream<Position> Function({LocationSettings? locationSettings});

class LocationService {
  // Default: Ho Chi Minh City center
  static const LatLng defaultLocation = LatLng(10.7769, 106.7009);
  static const LocationSettings _oneShotLocationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 10),
  );
  static const LocationSettings _foregroundStreamLocationSettings =
      LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);

  final LocationServiceEnabledReader _isLocationServiceEnabled;
  final LocationPermissionReader _permissionStatusReader;
  final LocationPermissionRequester _permissionRequester;
  final CurrentPositionReader _currentPositionReader;
  final PositionStreamReader _positionStreamReader;
  final StreamController<LatLng> _positionUpdates =
      StreamController<LatLng>.broadcast();

  LocationStatus _status = LocationStatus.loading;
  LatLng? _currentPosition;
  // ignore: cancel_subscriptions, canceled by stopPositionUpdates/dispose.
  StreamSubscription<Position>? _positionSubscription;
  bool _isDisposed = false;

  LocationService({
    LocationServiceEnabledReader? isLocationServiceEnabled,
    LocationPermissionReader? permissionStatusReader,
    LocationPermissionRequester? permissionRequester,
    CurrentPositionReader? currentPositionReader,
    PositionStreamReader? positionStreamReader,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _permissionStatusReader =
           permissionStatusReader ?? (() => Permission.location.status),
       _permissionRequester =
           permissionRequester ?? (() => Permission.location.request()),
       _currentPositionReader =
           currentPositionReader ??
           (({locationSettings}) => Geolocator.getCurrentPosition(
             locationSettings: locationSettings,
           )),
       _positionStreamReader =
           positionStreamReader ??
           (({locationSettings}) => Geolocator.getPositionStream(
             locationSettings: locationSettings,
           ));

  LocationStatus get status => _status;
  LatLng get currentPosition => _currentPosition ?? defaultLocation;
  bool get hasRealLocation => _currentPosition != null;
  Stream<LatLng> get positionUpdates => _positionUpdates.stream;
  bool get isStreamingPositionUpdates => _positionSubscription != null;

  /// Request/check location permission and get the current position once.
  /// Realtime listening is foreground-owned and starts via startPositionUpdates().
  Future<void> initialize() async {
    if (_isDisposed) return;

    final serviceEnabled = await _readServiceEnabled();
    if (!serviceEnabled) {
      _status = LocationStatus.serviceDisabled;
      await stopPositionUpdates();
      return;
    }

    final permissionStatus = await _ensurePermission();
    if (permissionStatus.isGranted) {
      _status = LocationStatus.granted;
      await _fetchPosition(emitUpdate: false);
    } else {
      await stopPositionUpdates();
      _status = permissionStatus.isPermanentlyDenied
          ? LocationStatus.deniedForever
          : LocationStatus.denied;
    }
  }

  Future<bool> _readServiceEnabled() async {
    try {
      return await _isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<PermissionStatus> _ensurePermission() async {
    final current = await _permissionStatusReader();
    if (current.isGranted || current.isPermanentlyDenied) {
      return current;
    }
    return _permissionRequester();
  }

  Future<void> _fetchPosition({required bool emitUpdate}) async {
    try {
      final position = await _currentPositionReader(
        locationSettings: _oneShotLocationSettings,
      );
      _applyPosition(position, emitUpdate: emitUpdate);
    } catch (_) {
      // Keep default or last known location on error.
    }
  }

  /// Start foreground realtime updates. Call from a visible screen lifecycle only.
  Future<void> startPositionUpdates() async {
    if (_isDisposed || _positionSubscription != null) return;
    if (_status != LocationStatus.granted) return;

    final serviceEnabled = await _readServiceEnabled();
    if (!serviceEnabled) {
      _status = LocationStatus.serviceDisabled;
      return;
    }

    _positionSubscription = _positionStreamReader(
      locationSettings: _foregroundStreamLocationSettings,
    ).listen(_handleRealtimePosition, onError: (_) {}, cancelOnError: false);
  }

  void _handleRealtimePosition(Position position) {
    _status = LocationStatus.granted;
    _applyPosition(position, emitUpdate: true);
  }

  void _applyPosition(Position position, {required bool emitUpdate}) {
    final nextPosition = LatLng(position.latitude, position.longitude);
    _currentPosition = nextPosition;

    if (emitUpdate && !_isDisposed && !_positionUpdates.isClosed) {
      _positionUpdates.add(nextPosition);
    }
  }

  /// Stop foreground realtime updates when the app/screen is not visible.
  Future<void> stopPositionUpdates() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
  }

  /// Refresh position after user grants permission from settings or gate screen.
  Future<void> refreshPosition() async {
    final permissionStatus = await _permissionStatusReader();
    if (permissionStatus.isGranted) {
      _status = LocationStatus.granted;
      await _fetchPosition(emitUpdate: true);
    } else {
      await stopPositionUpdates();
      _status = permissionStatus.isPermanentlyDenied
          ? LocationStatus.deniedForever
          : LocationStatus.denied;
    }
  }

  /// Open app settings for the permanently denied case.
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Open device location settings when GPS is disabled.
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await stopPositionUpdates();
    await _positionUpdates.close();
  }
}
