import 'dart:async';

import 'package:fidey_mobile/models/map_feed_item.dart';
import 'package:fidey_mobile/screens/home_screen.dart';
import 'package:fidey_mobile/services/location_service.dart';
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

  testWidgets('map mode toggle switches between friends and private labels', (
    tester,
  ) async {
    var mode = MapFeedMode.friends;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: MapModeToggleButton(
              mode: mode,
              onTap: () => setState(() {
                mode = mode == MapFeedMode.friends
                    ? MapFeedMode.private
                    : MapFeedMode.friends;
              }),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Bạn bè'), findsOneWidget);

    await tester.tap(find.byType(MapModeToggleButton));
    await tester.pump();

    expect(find.text('Riêng tư'), findsOneWidget);
  });

  test('map feed marker presentation uses place category and short label', () {
    final cafe = MapFeedItem(
      id: 'checkin-1',
      caption: '',
      createdAt: DateTime(2026, 6, 22, 9),
      mediaId: 'media-1',
      userId: 'friend-1',
      userName: 'An',
      placeId: 'place-1',
      placeName: 'Bamos Coffee & Tea Thu Duc',
      category: 'cafe',
      lat: 10.77,
      lng: 106.70,
    );

    final restaurant = MapFeedItem(
      id: 'checkin-2',
      caption: '',
      createdAt: DateTime(2026, 6, 22, 9),
      mediaId: 'media-2',
      userId: 'friend-2',
      userName: 'Binh',
      placeId: 'place-2',
      placeName: 'Quán ăn gia đình',
      category: 'restaurant',
      lat: 10.78,
      lng: 106.71,
    );

    expect(
      MapFeedMarkerPresentation.fromItem(cafe).icon,
      Icons.local_cafe_rounded,
    );
    expect(
      MapFeedMarkerPresentation.fromItem(cafe).label,
      'Bamos Coffee &…',
    );
    expect(
      MapFeedMarkerPresentation.fromItem(restaurant).icon,
      Icons.restaurant_rounded,
    );
  });

  test('map feed marker label width follows text with compact padding', () {
    expect(
      MapFeedMarkerPresentation.labelPillWidth(30),
      44,
    );
    expect(
      MapFeedMarkerPresentation.labelPillWidth(80),
      86,
    );
    expect(
      MapFeedMarkerPresentation.labelPillWidth(220),
      160,
    );
  });

  testWidgets('feed place sheet shows candidate place without fake check-in', (
    tester,
  ) async {
    final item = MapFeedItem(
      id: 'candidate-candidate-1',
      caption: '',
      createdAt: DateTime(2026, 6, 22, 9),
      mediaId: '',
      userId: 'user-1',
      userName: 'Minh',
      userAvatar: null,
      placeId: 'candidate-1',
      placeName: 'Cafe mới',
      category: 'cafe',
      address: '12 Nguyen Hue',
      lat: 10.77,
      lng: 106.70,
      isCandidate: true,
      createdByName: 'Minh',
      candidateStatus: 'PENDING_REVIEW',
      placeCheckinCount: 0,
      recentUserNames: const ['Minh'],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FeedPlaceSheet(item: item))),
    );

    expect(find.text('Cafe mới'), findsOneWidget);
    expect(find.text('Chưa có check-in'), findsOneWidget);
    expect(find.text('Tạo bởi Minh'), findsOneWidget);
    expect(find.text('Minh đã tạo địa điểm này'), findsOneWidget);
    expect(find.text('1 check-ins gần đây'), findsNothing);
    expect(find.textContaining('vừa check-in'), findsNothing);
  });

  testWidgets('feed place sheet shows place address and social activity', (
    tester,
  ) async {
    final item = MapFeedItem(
      id: 'checkin-1',
      caption: 'Không gian yên tĩnh',
      createdAt: DateTime(2026, 6, 22, 9),
      mediaId: 'media-1',
      userId: 'friend-1',
      userName: 'An',
      userAvatar: null,
      placeId: 'candidate-1',
      placeName: 'Cafe mới',
      category: 'cafe',
      address: '12 Nguyen Hue',
      lat: 10.77,
      lng: 106.70,
      isCandidate: true,
      createdByName: 'Minh',
      candidateStatus: 'PENDING_REVIEW',
      placeCheckinCount: 3,
      recentUserNames: const ['An', 'Binh'],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FeedPlaceSheet(item: item))),
    );

    expect(find.text('Cafe mới'), findsOneWidget);
    expect(find.text('12 Nguyen Hue'), findsOneWidget);
    expect(find.text('Địa điểm bạn bè đề xuất'), findsOneWidget);
    expect(find.text('3 check-ins gần đây'), findsOneWidget);
    expect(find.textContaining('An vừa check-in'), findsOneWidget);
    expect(find.text('Xem chi tiết'), findsOneWidget);
  });
}
