library;

class DashboardPlace {
  final String id;
  final String name;
  final String category;
  final double rating;
  final double distanceKm; // Lưu trữ dưới dạng km để hiển thị lên UI chuẩn
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
        : "https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=500";

    return DashboardPlace(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Chưa cập nhật tên',
      category: json['category'] as String? ?? 'Restaurant',

      // Parse rating an toàn, ưu tiên lấy số thực từ hệ thống
      rating: double.tryParse(json['avg_rating']?.toString() ?? '') ??
          double.tryParse(metadata['rating']?.toString() ?? '') ?? 4.0,

      distanceKm: calculatedKm, // Đã quy đổi chuẩn (Ví dụ: 300m -> 0.3km)
      imageUrl: validImageUrl,

      // Khớp chính xác với trường checkin_count mà hàm Lambda backend trả về
      friendsCount: int.tryParse(json['checkin_count']?.toString() ?? '') ?? 1,
    );
  }
}