import 'package:fidee_mobile/models/custom_address_validation.dart';
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
    Future<SelectedPlaceTag?> Function(
      String name,
      String visibility,
      String? address,
    )? onCreateCustomPlace,
    Future<String?> Function()? onResolveCustomAddress,
    Future<CustomAddressValidation?> Function(String address)?
        onValidateCustomAddress,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PlacePickerSheetContent(
          places: places,
          onSelected: onSelected ?? (_) {},
          onCreateCustomPlace: onCreateCustomPlace,
          onResolveCustomAddress: onResolveCustomAddress,
          onValidateCustomAddress: onValidateCustomAddress,
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
    String? submittedAddress;

    await tester.pumpWidget(
      buildSheet(
        places: const [],
        onSelected: (place) => selected = place,
        onCreateCustomPlace: (name, visibility, address) async {
          submittedAddress = address;
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

    expect(find.byKey(const ValueKey('place-search-field')), findsNothing);
    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.text('Riêng tư'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom-place-address-field')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-name-field')),
      'Há Há Há',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-address-field')),
      '12 Nguyen Hue',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump();

    expect(selected?.displayName, 'Há Há Há');
    expect(selected?.source, 'custom');
    expect(submittedAddress, '12 Nguyen Hue');
  });

  testWidgets('prefills custom place address from current coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSheet(
        places: const [],
        onResolveCustomAddress: () async => '91 Trung Kinh, Ha Noi',
      ),
    );

    await tester.tap(find.text('Thêm địa điểm tùy chỉnh'));
    await tester.pump();
    await tester.pump();

    expect(find.text('91 Trung Kinh, Ha Noi'), findsOneWidget);
  });

  testWidgets('shows a soft warning when custom address is far away', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSheet(
        places: const [],
        onCreateCustomPlace: (name, visibility, address) async {
          return SelectedPlaceTag(
            id: 'custom-1',
            displayName: name,
            address: address ?? '',
            lat: 10.2,
            lng: 106.2,
            source: 'custom',
          );
        },
        onValidateCustomAddress: (address) async {
          return const CustomAddressValidation(
            isFarFromCurrentLocation: true,
            distanceMeters: 850,
          );
        },
      ),
    );

    await tester.tap(find.text('Thêm địa điểm tùy chỉnh'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-name-field')),
      'Quán xa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-address-field')),
      '91 Trung Kinh',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('cách xa vị trí hiện tại'), findsOneWidget);
  });

  testWidgets('passes private visibility when creating a custom place', (
    tester,
  ) async {
    String? submittedVisibility;

    await tester.pumpWidget(
      buildSheet(
        places: const [],
        onCreateCustomPlace: (name, visibility, address) async {
          submittedVisibility = visibility;
          return SelectedPlaceTag(
            id: 'custom-1',
            displayName: name,
            address: visibility,
            lat: 10.2,
            lng: 106.2,
            source: 'custom',
          );
        },
      ),
    );

    await tester.tap(find.text('Thêm địa điểm tùy chỉnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Riêng tư'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('custom-place-name-field')),
      'Quán riêng',
    );
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pump();

    expect(submittedVisibility, 'PRIVATE');
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
