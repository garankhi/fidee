import '../config.dart';

enum JourneyEntryType { checkin, review }

class JourneyEntry {
  final JourneyEntryType type;
  final String id;
  final String placeId;
  final String placeName;
  final String? category;
  final String createdAt;
  final int? rating;
  final String? text;
  final String? mediaId;
  final List<String> tags;
  final int friendsSavedCount;

  const JourneyEntry({
    required this.type,
    required this.id,
    required this.placeId,
    required this.placeName,
    this.category,
    required this.createdAt,
    this.rating,
    this.text,
    this.mediaId,
    this.tags = const <String>[],
    this.friendsSavedCount = 0,
  });

  factory JourneyEntry.fromJson(
    Map<String, dynamic> json, {
    required JourneyEntryType type,
  }) {
    return JourneyEntry(
      type: type,
      id: json['id'] as String? ?? '',
      placeId: json['placeId'] as String? ?? '',
      placeName: json['placeName'] as String? ?? 'Place',
      category: json['category'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt(),
      text:
          (type == JourneyEntryType.review ? json['content'] : json['caption'])
              as String?,
      mediaId:
          (type == JourneyEntryType.review
                  ? json['coverMediaId']
                  : json['mediaId'])
              as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
      friendsSavedCount: (json['friendsSavedCount'] as num?)?.toInt() ?? 0,
    );
  }

  DateTime? get createdDate => DateTime.tryParse(createdAt)?.toLocal();

  String? get imageUrl {
    final value = mediaId;
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${Config.apiBaseUrl}/media/$value';
  }

  String relativeTime({DateTime? now}) {
    final created = DateTime.tryParse(createdAt);
    if (created == null) return '';

    final difference = (now ?? DateTime.now().toUtc()).difference(
      created.toUtc(),
    );
    if (difference.inDays >= 365) return '${difference.inDays ~/ 365}y';
    if (difference.inDays >= 30) return '${difference.inDays ~/ 30}mo';
    if (difference.inDays >= 1) return '${difference.inDays}d';
    if (difference.inHours >= 1) return '${difference.inHours}h';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m';
    return 'now';
  }
}

class JourneyPage {
  final List<JourneyEntry> entries;
  final String? nextCursor;
  final bool hasMore;

  const JourneyPage({
    required this.entries,
    this.nextCursor,
    required this.hasMore,
  });
}
