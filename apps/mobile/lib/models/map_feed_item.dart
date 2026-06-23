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
  final String? address;
  final double lat;
  final double lng;
  final String? visibility;
  final String? checkinVisibility;
  final bool isCandidate;
  final String? createdBy;
  final String? createdByName;
  final String? createdByAvatar;
  final String? candidateStatus;
  final int placeCheckinCount;
  final List<String> recentAvatars;
  final List<String> recentUserNames;

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
    this.address,
    required this.lat,
    required this.lng,
    this.visibility,
    this.checkinVisibility,
    this.isCandidate = false,
    this.createdBy,
    this.createdByName,
    this.createdByAvatar,
    this.candidateStatus,
    this.placeCheckinCount = 1,
    this.recentAvatars = const <String>[],
    this.recentUserNames = const <String>[],
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
      address: json['address'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      visibility: json['visibility'] as String?,
      checkinVisibility: json['checkinVisibility'] as String?,
      isCandidate: json['isCandidate'] as bool? ?? false,
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      createdByAvatar: json['createdByAvatar'] as String?,
      candidateStatus: json['candidateStatus'] as String?,
      placeCheckinCount: (json['placeCheckinCount'] as num?)?.toInt() ?? 1,
      recentAvatars: _stringList(json['recentAvatars']),
      recentUserNames: _stringList(json['recentUserNames']),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.whereType<String>().toList(growable: false);
}
