import '../config.dart';

enum CameraFeedAudienceType { everyone, me, friend }

class CameraFeedAudience {
  final CameraFeedAudienceType type;
  final String label;
  final String? id;
  final String? avatarUrl;

  const CameraFeedAudience._({
    required this.type,
    required this.label,
    this.id,
    this.avatarUrl,
  });

  factory CameraFeedAudience.everyone() {
    return const CameraFeedAudience._(
      type: CameraFeedAudienceType.everyone,
      label: 'Mọi người',
    );
  }

  factory CameraFeedAudience.me({String? avatarUrl}) {
    return CameraFeedAudience._(
      type: CameraFeedAudienceType.me,
      label: 'Bạn',
      avatarUrl: avatarUrl,
    );
  }

  factory CameraFeedAudience.friend({
    required String id,
    required String label,
    String? avatarUrl,
  }) {
    return CameraFeedAudience._(
      type: CameraFeedAudienceType.friend,
      id: id,
      label: label,
      avatarUrl: avatarUrl,
    );
  }
}

class CameraCheckinFeedItem {
  final String id;
  final String? caption;
  final int? rating;
  final String createdAt;
  final String? mediaId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String placeId;
  final String placeName;
  final String? category;

  const CameraCheckinFeedItem({
    required this.id,
    this.caption,
    this.rating,
    required this.createdAt,
    this.mediaId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.placeId,
    required this.placeName,
    this.category,
  });

  factory CameraCheckinFeedItem.fromJson(Map<String, dynamic> json) {
    return CameraCheckinFeedItem(
      id: json['id'] as String? ?? '',
      caption: json['caption'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? '',
      mediaId: json['mediaId'] as String?,
      userId: json['userId'] as String? ?? '',
      userName: json['userName'] as String? ?? 'Bạn bè',
      userAvatar: json['userAvatar'] as String?,
      placeId: json['placeId'] as String? ?? '',
      placeName: json['placeName'] as String? ?? 'Địa điểm',
      category: json['category'] as String?,
    );
  }

  String get imageUrl {
    if (mediaId == null || mediaId!.isEmpty) return '';
    return '${Config.apiBaseUrl}/media/$mediaId';
  }

  String get categoryLabel {
    return switch (category?.toLowerCase()) {
      'restaurant' || 'food' => 'Nhà hàng',
      'cafe' || 'coffee' => 'Cà phê',
      'bar' || 'pub' => 'Bar',
      'bakery' || 'dessert' => 'Đồ ngọt',
      _ => category ?? 'Địa điểm',
    };
  }

  String relativeTime({DateTime? now}) {
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';

    final diff = (now ?? DateTime.now().toUtc()).difference(created.toUtc());
    if (diff.inDays >= 1) return '${diff.inDays}n';
    if (diff.inHours >= 1) return '${diff.inHours}g';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}p';
    return 'vừa xong';
  }
}

class CameraCheckinFeedPage {
  final List<CameraCheckinFeedItem> items;
  final String? nextCursor;
  final bool hasMore;

  const CameraCheckinFeedPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  factory CameraCheckinFeedPage.empty() {
    return const CameraCheckinFeedPage(
      items: <CameraCheckinFeedItem>[],
      hasMore: false,
    );
  }
}
