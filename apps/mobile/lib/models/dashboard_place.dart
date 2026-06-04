library;

class DashboardPlace {
  final String id;
  final String name;
  final String category;
  final double rating;
  final double distanceKm;
  final String imageUrl;
  final int friendsCount;

  const DashboardPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.rating,
    required this.distanceKm,
    required this.imageUrl,
    required this.friendsCount,
  });

  factory DashboardPlace.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    return DashboardPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chưa cập nhật tên',
      category: json['category'] as String? ?? 'Restaurant',
      rating: double.tryParse(metadata['rating']?.toString() ?? '4.9') ?? 4.9,
      distanceKm: double.tryParse(json['distance_meters']?.toString() ?? '300') ?? 0.3,
      imageUrl: metadata['image_url'] as String? ?? "https://placehold.co/265x220",
      friendsCount: int.tryParse(json['checkin_count']?.toString() ?? '10') ?? 10,
    );
  }
}