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
  @override
  Place build() {
    return const Place();
  }

  // Cập nhật thông tin cơ bản của địa điểm
  void updateBasicInfo(String name, String category, String address) {
    state = state.copyWith(name: name, category: category, address: address);
  }

  // Cập nhật tọa độ bản đồ
  void updateCoordinates(double lat, double lng) {
    state = state.copyWith(lat: lat, lng: lng);
  }

  // Cập nhật khung giờ hoạt động
  void updateOperatingHours(String openTime, String closeTime) {
    state = state.copyWith(openTime: openTime, closeTime: closeTime);
  }

  // Reset trạng thái về trống
  void clear() {
    state = const Place();
  }
}