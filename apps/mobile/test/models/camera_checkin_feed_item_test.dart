import 'package:fidee_mobile/models/camera_checkin_feed_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CameraCheckinFeedItem', () {
    test('parses API row and derives image/category/time labels', () {
      final item = CameraCheckinFeedItem.fromJson(const <String, dynamic>{
        'id': 'checkin-1',
        'caption': 't bi ghiền r',
        'rating': 5,
        'createdAt': '2026-06-09T08:30:00.000Z',
        'mediaId': 'media-1',
        'userId': 'user-2',
        'userName': 'Lan Tran',
        'userAvatar': 'https://cdn.example/lan.png',
        'placeId': 'place-1',
        'placeName': 'Rice & Curry',
        'category': 'restaurant',
      });

      expect(item.id, 'checkin-1');
      expect(item.caption, 't bi ghiền r');
      expect(item.imageUrl, 'https://api.fidee.site/media/media-1');
      expect(item.categoryLabel, 'Nhà hàng');
      expect(
        item.relativeTime(now: DateTime.parse('2026-06-09T21:30:00.000Z')),
        '13g',
      );
    });

    test('parses video media type from API row', () {
      final item = CameraCheckinFeedItem.fromJson(const <String, dynamic>{
        'id': 'checkin-video-1',
        'createdAt': '2026-06-09T08:30:00.000Z',
        'mediaId': 'video-1',
        'mediaType': 'VIDEO',
        'userId': 'user-2',
        'userName': 'Lan Tran',
        'placeId': 'place-1',
        'placeName': 'Cafe',
      });

      expect(item.mediaType, CameraCheckinMediaType.video);
      expect(item.isVideo, isTrue);
    });

    test('defaults unknown media type to image', () {
      final item = CameraCheckinFeedItem.fromJson(const <String, dynamic>{
        'id': 'checkin-image-1',
        'createdAt': '2026-06-09T08:30:00.000Z',
        'mediaId': 'media-1',
        'mediaType': 'GIF',
        'userId': 'user-2',
        'userName': 'Lan Tran',
        'placeId': 'place-1',
        'placeName': 'Cafe',
      });

      expect(item.mediaType, CameraCheckinMediaType.image);
      expect(item.isVideo, isFalse);
    });

    test('keeps empty image URL when mediaId is missing', () {
      final item = CameraCheckinFeedItem.fromJson(const <String, dynamic>{
        'id': 'checkin-2',
        'createdAt': '2026-06-09T08:30:00.000Z',
        'userId': 'user-2',
        'userName': 'Lan Tran',
        'placeId': 'place-1',
        'placeName': 'Cafe',
      });

      expect(item.imageUrl, isEmpty);
      expect(item.rating, isNull);
    });
  });
}
