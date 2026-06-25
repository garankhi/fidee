import 'dart:async';

import 'package:fidey_mobile/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  Position position(double latitude, double longitude) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 6, 14),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  LocationService buildService({
    required StreamController<Position> realtimeController,
    Position? currentPosition,
    bool serviceEnabled = true,
    PermissionStatus permissionStatus = PermissionStatus.granted,
    void Function()? onStreamStarted,
  }) {
    return LocationService(
      isLocationServiceEnabled: () async => serviceEnabled,
      permissionStatusReader: () async => permissionStatus,
      permissionRequester: () async => permissionStatus,
      currentPositionReader: ({locationSettings}) async =>
          currentPosition ?? position(10.7769, 106.7009),
      positionStreamReader: ({locationSettings}) {
        onStreamStarted?.call();
        return realtimeController.stream;
      },
    );
  }

  test(
    'initialize fetches a one-shot position without starting realtime',
    () async {
      final realtimeController = StreamController<Position>.broadcast();
      addTearDown(realtimeController.close);
      var streamStartCount = 0;
      final service = buildService(
        realtimeController: realtimeController,
        currentPosition: position(10.8, 106.7),
        onStreamStarted: () => streamStartCount += 1,
      );
      addTearDown(service.dispose);

      await service.initialize();

      expect(service.status, LocationStatus.granted);
      expect(service.currentPosition, const LatLng(10.8, 106.7));
      expect(service.isStreamingPositionUpdates, isFalse);
      expect(streamStartCount, 0);
    },
  );

  test(
    'startPositionUpdates emits positions and updates currentPosition',
    () async {
      final realtimeController = StreamController<Position>.broadcast();
      addTearDown(realtimeController.close);
      final service = buildService(realtimeController: realtimeController);
      addTearDown(service.dispose);
      final emitted = <LatLng>[];
      final subscription = service.positionUpdates.listen(emitted.add);
      addTearDown(subscription.cancel);

      await service.initialize();
      await service.startPositionUpdates();
      realtimeController.add(position(10.9, 106.8));
      await pumpEventQueue();

      expect(service.isStreamingPositionUpdates, isTrue);
      expect(service.currentPosition, const LatLng(10.9, 106.8));
      expect(emitted, const <LatLng>[LatLng(10.9, 106.8)]);
    },
  );

  test('startPositionUpdates is idempotent', () async {
    final realtimeController = StreamController<Position>.broadcast();
    addTearDown(realtimeController.close);
    var streamStartCount = 0;
    final service = buildService(
      realtimeController: realtimeController,
      onStreamStarted: () => streamStartCount += 1,
    );
    addTearDown(service.dispose);

    await service.initialize();
    await service.startPositionUpdates();
    await service.startPositionUpdates();

    expect(service.isStreamingPositionUpdates, isTrue);
    expect(streamStartCount, 1);
  });

  test('stopPositionUpdates cancels foreground realtime listening', () async {
    final realtimeController = StreamController<Position>.broadcast();
    addTearDown(realtimeController.close);
    final service = buildService(realtimeController: realtimeController);
    addTearDown(service.dispose);
    final emitted = <LatLng>[];
    final subscription = service.positionUpdates.listen(emitted.add);
    addTearDown(subscription.cancel);

    await service.initialize();
    await service.startPositionUpdates();
    await service.stopPositionUpdates();
    realtimeController.add(position(11, 107));
    await pumpEventQueue();

    expect(service.isStreamingPositionUpdates, isFalse);
    expect(emitted, isEmpty);
  });
}
