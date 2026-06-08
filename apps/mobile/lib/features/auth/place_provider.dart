import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'place_provider.g.dart';

class Place {
  final String? id;
  final String? name;
  final String? category;
  final String? address;
  final double? lat;
  final double? lng;
  final String? openTime;
  final String? closeTime;

  const Place({
    this.id,
    this.name,
    this.category,
    this.address,
    this.lat,
    this.lng,
    this.openTime,
    this.closeTime,
  });

  Place copyWith({
    String? id,
    String? name,
    String? category,
    String? address,
    double? lat,
    double? lng,
    String? openTime,
    String? closeTime,
  }) {
    return Place(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

@riverpod
class PlaceController extends _$PlaceController {
  // @override
  // Place build() {
  //   return const Place();
  // }

  //Mockdata
  @override
  Place build() {
  return const Place(
  id: 'fea3bae4-9fb7-4fea-abe0-521d3e6ef2fd',
  name: 'Quán Trà Sữa Full Option',
  category: 'Cafe',
  address: 'Phố đi bộ Nguyễn Huệ, Quận 1',
  lat: 10.7738,
  lng: 106.7035,
  openTime: '08:00',
  closeTime: '22:00',
  );
  }

  void updateBasicInfo(String name, String category, String address) {
    state = state.copyWith(name: name, category: category, address: address);
  }

  void updateCoordinates(double lat, double lng) {
    state = state.copyWith(lat: lat, lng: lng);
  }

  void updateOperatingHours(String openTime, String closeTime) {
    state = state.copyWith(openTime: openTime, closeTime: closeTime);
  }

  void clear() {
    state = const Place();
  }
}