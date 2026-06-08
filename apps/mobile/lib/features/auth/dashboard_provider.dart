import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../models/dashboard_place.dart';

part 'dashboard_provider.g.dart';

class DashboardState {
  final List<DashboardPlace> hotPlaces;
  final List<DashboardPlace> friendActivities;
  final String? selectedVibe;

  const DashboardState({
    this.hotPlaces = const [],
    this.friendActivities = const [],
    this.selectedVibe,
  });

  DashboardState copyWith({
    List<DashboardPlace>? hotPlaces,
    List<DashboardPlace>? friendActivities,
    String? selectedVibe,
  }) {
    return DashboardState(
      hotPlaces: hotPlaces ?? this.hotPlaces,
      friendActivities: friendActivities ?? this.friendActivities,
      selectedVibe: selectedVibe ?? this.selectedVibe,
    );
  }
}

@riverpod
class DashboardController extends _$DashboardController {
  // @override
  // DashboardState build() {
  //   return const DashboardState();
  // }

  //Mockdata
  @override
  DashboardState build() {
    return const DashboardState(
      hotPlaces: [
        DashboardPlace(
          id: 'fea3bae4-9fb7-4fea-abe0-521d3e6ef2fd',
          name: 'Quán Trà Sữa Full Option',
          category: 'Cafe',
          rating: 4.0,
          distanceKm: 0.3,
          imageUrl: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500',
          friendsCount: 1,
        ),
      ],
      friendActivities: [
        DashboardPlace(
          id: 'fea3bae4-9fb7-4fea-abe0-521d3e6ef2fd',
          name: 'Quán Trà Sữa Full Option',
          category: 'Cafe',
          rating: 4.0,
          distanceKm: 0.8,
          imageUrl: 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=150',
          friendsCount: 1,
        ),
      ],
      selectedVibe: 'Cafe',
    );
  }

  // Cập nhật danh sách địa điểm đang hot
  void updateHotPlaces(List<DashboardPlace> places) {
    state = state.copyWith(hotPlaces: places);
  }

  // Cập nhật danh sách hoạt động của bạn bè
  void updateFriendActivities(List<DashboardPlace> activities) {
    state = state.copyWith(friendActivities: activities);
  }

  // Thay đổi Vibe được chọn hiện tại trên màn hình
  void selectVibe(String vibe) {
    state = state.copyWith(selectedVibe: vibe);
  }

  // Xóa toàn bộ dữ liệu trạng thái nháp
  void clear() {
    state = const DashboardState();
  }
}