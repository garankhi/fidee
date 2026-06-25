import 'package:fidey_mobile/models/nearby_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses friend candidate with nullable address from nearby API', () {
    final place = NearbyPlace.fromJson({
      'id': 'candidate-1',
      'place_id': null,
      'source': 'friend_candidate',
      'display_name': 'Há Há Há',
      'address': null,
      'category': 'restaurant',
      'distance_meters': 0,
      'confidence': 'high',
      'coordinates': {'lat': 10.7738, 'lng': 106.7035},
      'actions': {'primary': 'select'},
    });

    expect(place.displayName, 'Há Há Há');
    expect(place.address, 'Địa điểm tùy chỉnh');
    expect(place.isCustomFallback, isFalse);
  });

  test('defaults missing actions from nearby API to select', () {
    final place = NearbyPlace.fromJson({
      'id': 'candidate-2',
      'place_id': null,
      'source': 'friend_candidate',
      'display_name': 'Quán mới tạo',
      'address': null,
      'category': 'restaurant',
      'distance_meters': 7,
      'confidence': 'high',
      'coordinates': {'lat': 10.7738, 'lng': 106.7035},
    });

    expect(place.actions.primary, 'select');
  });

  test('only treats the explicit custom fallback row as fallback', () {
    final customPlace = NearbyPlace.fromJson({
      'id': 'custom-place-1',
      'place_id': null,
      'source': 'custom',
      'display_name': 'Quán tự tạo',
      'address': 'Gần vị trí hiện tại',
      'category': 'restaurant',
      'distance_meters': 4,
      'confidence': 'high',
      'coordinates': {'lat': 10.7738, 'lng': 106.7035},
      'actions': {'primary': 'select'},
    });

    expect(customPlace.isCustomFallback, isFalse);
  });

  test('parses numeric strings from nearby API', () {
    final place = NearbyPlace.fromJson({
      'id': 'place-1',
      'place_id': 'place-1',
      'source': 'internal',
      'display_name': 'Approved Coffee',
      'address': '456 Nguyen Hue',
      'category': 'restaurant',
      'distance_meters': '42.4',
      'confidence': 'medium',
      'coordinates': {'lat': '10.7738', 'lng': '106.7035'},
    });

    expect(place.distanceMeters, 42);
    expect(place.coordinates.lat, 10.7738);
    expect(place.coordinates.lng, 106.7035);
  });
}
