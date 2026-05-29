import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

enum LocationStatus { loading, granted, denied, deniedForever, serviceDisabled }

class LocationService {
  // Default: Ho Chi Minh City center
  static const LatLng defaultLocation = LatLng(10.7769, 106.7009);

  LocationStatus _status = LocationStatus.loading;
  LatLng? _currentPosition;

  LocationStatus get status => _status;
  LatLng get currentPosition => _currentPosition ?? defaultLocation;
  bool get hasRealLocation => _currentPosition != null;

  /// Request location permission and get current position.
  Future<void> initialize() async {
    // 1. Check if location service is enabled
    bool serviceEnabled;
    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      serviceEnabled = false;
    }
    
    if (!serviceEnabled) {
      _status = LocationStatus.serviceDisabled;
      return;
    }

    // 2. Request permission
    final permissionStatus = await Permission.location.request();

    if (permissionStatus.isGranted) {
      _status = LocationStatus.granted;
      await _fetchPosition();
    } else if (permissionStatus.isPermanentlyDenied) {
      _status = LocationStatus.deniedForever;
    } else {
      _status = LocationStatus.denied;
    }
  }

  /// Fetch current GPS position.
  Future<void> _fetchPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _currentPosition = LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Keep default location on error
    }
  }

  /// Refresh position (call after user grants permission from settings).
  Future<void> refreshPosition() async {
    final permissionStatus = await Permission.location.status;
    if (permissionStatus.isGranted) {
      _status = LocationStatus.granted;
      await _fetchPosition();
    }
  }

  /// Open app settings (for "permanently denied" case).
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
