import 'dart:async';

import 'package:fidee_mobile/screens/home_screen.dart';
import 'package:fidee_mobile/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _ForegroundLocationService extends LocationService {
  final StreamController<LatLng> _positions =
      StreamController<LatLng>.broadcast();
  int startCount = 0;
  int stopCount = 0;

  @override
  LocationStatus get status => LocationStatus.granted;

  @override
  bool get hasRealLocation => false;

  @override
  Stream<LatLng> get positionUpdates => _positions.stream;

  @override
  Future<void> startPositionUpdates() async {
    startCount += 1;
  }

  @override
  Future<void> stopPositionUpdates() async {
    stopCount += 1;
  }

  Future<void> close() async {
    await _positions.close();
  }
}

void main() {
  setUp(() {
    dotenv.loadFromString(isOptional: true);
  });

  tearDown(() {
    dotenv.loadFromString(isOptional: true);
  });

  testWidgets('shows a non-blocking Goong key fallback when key is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: HomeScreen(locationService: LocationService()),
        ),
      ),
    );

    expect(find.text('GOONG_MAPTILES_KEY chưa được cấu hình.'), findsOneWidget);
  });

  testWidgets('starts and stops foreground location updates with the screen', (
    tester,
  ) async {
    final locationService = _ForegroundLocationService();
    addTearDown(locationService.close);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: HomeScreen(locationService: locationService)),
      ),
    );

    expect(locationService.startCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(locationService.stopCount, 1);
  });
}
