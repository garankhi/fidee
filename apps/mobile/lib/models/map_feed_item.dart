class MapFeedItem {
  final String id;
  final String caption;
  final DateTime createdAt;
  final String mediaId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String placeId;
  final String placeName;
  final String category;
  final double lat;
  final double lng;

  const MapFeedItem({
    required this.id,
    required this.caption,
    required this.createdAt,
    required this.mediaId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.placeId,
    required this.placeName,
    required this.category,
    required this.lat,
    required this.lng,
  });

  factory MapFeedItem.fromJson(Map<String, dynamic> json) {
    return MapFeedItem(
      id: json['id'] as String,
      caption: json['caption'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      mediaId: json['mediaId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userAvatar: json['userAvatar'] as String?,
      placeId: json['placeId'] as String,
      placeName: json['placeName'] as String,
      category: json['category'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}
