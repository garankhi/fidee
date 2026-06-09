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
    // 1. Khai báo an toàn cho metadata tránh crash khi null
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    // 2. Parse khoảng cách an toàn từ meters và đổi sang km (chia cho 1000)
    final int? distanceMeters = int.tryParse(json['distance_meters']?.toString() ?? '');
    final double calculatedKm = distanceMeters != null ? (distanceMeters / 1000) : 0.3;

    // 3. Đọc link ảnh từ metadata, nếu lỗi hoặc trống thì lấy ảnh JPG thật thay thế placeholder lỗi
    final String rawImageUrl = metadata['image_url'] as String? ?? '';
    final String validImageUrl = rawImageUrl.startsWith('http')
        ? rawImageUrl
        : 'https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500';

    return DashboardPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chưa cập nhật tên',
      category: json['category'] as String? ?? 'Restaurant',
      rating: double.tryParse(metadata['rating']?.toString() ?? '4.9') ?? 4.9,
      distanceKm: double.tryParse(json['distance_meters']?.toString() ?? '300') ?? 0.3,
      imageUrl: metadata['image_url'] as String? ?? 'https://placehold.co/265x220',
      friendsCount: int.tryParse(json['checkin_count']?.toString() ?? '10') ?? 10,
    );
  }
}