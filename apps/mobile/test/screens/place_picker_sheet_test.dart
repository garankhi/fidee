import 'package:fidee_mobile/models/nearby_place.dart';
import 'package:fidee_mobile/models/selected_place_tag.dart';
import 'package:fidee_mobile/screens/place_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const samplePlace = NearbyPlace(
  id: 'nearby-1',
  placeId: 'goong-1',
  source: 'goong_places',
  displayName: 'Marukame Udon',
  address: '123 Le Van Viet, TP.HCM',
  category: 'restaurant',
  distanceMeters: 18,
  confidence: 'high',
  coordinates: NearbyPlaceCoordinates(lat: 10.1, lng: 106.1),
  actions: NearbyPlaceActions(primary: 'select'),
);

const customCandidatePlace = NearbyPlace(
  id: 'candidate-1',
  placeId: null,
  source: 'friend_candidate',
  displayName: 'Há Há Há',
  address: 'Địa điểm tùy chỉnh',
  category: 'restaurant',
  distanceMeters: 0,
  confidence: 'high',
  coordinates: NearbyPlaceCoordinates(lat: 10.2, lng: 106.2),
  actions: NearbyPlaceActions(primary: 'select'),
);

void main() {
  Widget buildSheet({
    List<NearbyPlace> places = const [samplePlace],
    void Function(SelectedPlaceTag place)? onSelected,
    Future<SelectedPlaceTag?> Function(String name)? onCreateCustomPlace,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlacePickerSheetContent(
          places: places,
          onSelected: onSelected ?? (_) {},
          onCreateCustomPlace: onCreateCustomPlace,
        ),
      ),
    );
  }

  testWidgets('selects a nearby place from the sheet', (tester) async {
    SelectedPlaceTag? selected;

    await tester.pumpWidget(
      buildSheet(onSelected: (place) => selected = place),
    );

    await tester.tap(find.text('Marukame Udon'));
    await tester.pump();

    expect(selected?.displayName, 'Marukame Udon');
    expect(selected?.lat, 10.1);
    expect(selected?.lng, 106.1);
  });

  testWidgets('shows custom place action when no places match', (tester) async {
    await tester.pumpWidget(buildSheet(places: const []));

    expect(find.text('Hmm... Có vẻ là'), findsOneWidget);
    expect(find.text('địa điểm này chưa có trên bản đồ'), findsOneWidget);
    expect(find.text('Thêm địa điểm tùy chỉnh'), findsOneWidget);
  });

  testWidgets('creates a custom place from the compact form', (tester) async {
    SelectedPlaceTag? selected;

    await tester.pumpWidget(
      buildSheet(
        places: const [],
        onSelected: (place) => selected = place,
        onCreateCustomPlace: (name) async {
          return SelectedPlaceTag(
            id: 'custom-1',
            displayName: name,
            address: 'Được tạo bởi Bạn',
            lat: 10.2,
            lng: 106.2,
            source: 'custom',
          );
        },
      ),
    );

    await tester.tap(find.text('Thêm địa điểm tùy chỉnh'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-name-field')),
      'Há Há Há',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump();

    expect(selected?.displayName, 'Há Há Há');
    expect(selected?.source, 'custom');
  });

  testWidgets('filters nearby places by search text', (tester) async {
    await tester.pumpWidget(
      buildSheet(places: const [samplePlace, customCandidatePlace]),
    );

    await tester.enterText(
      find.byKey(const ValueKey('place-search-field')),
      'há há',
    );
    await tester.pump();

    expect(find.text('Há Há Há'), findsOneWidget);
    expect(find.text('Marukame Udon'), findsNothing);
  });
}
