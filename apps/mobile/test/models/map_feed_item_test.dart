import 'package:fidey_mobile/models/map_feed_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses upgraded map feed metadata for place markers', () {
    final item = MapFeedItem.fromJson({
      'id': 'checkin-1',
      'caption': 'Nice coffee',
      'createdAt': '2026-06-22T09:00:00.000Z',
      'mediaId': 'media-1',
      'mediaType': 'IMAGE',
      'userId': 'friend-1',
      'userName': 'An',
      'userAvatar': 'https://example.com/an.png',
      'placeId': 'candidate-1',
      'placeName': 'Cafe mới',
      'category': 'cafe',
      'address': '12 Nguyen Hue',
      'lat': 10.7738,
      'lng': 106.7035,
      'visibility': 'FRIENDS',
      'checkinVisibility': 'FRIENDS',
      'isCandidate': true,
      'createdBy': 'user-1',
      'createdByName': 'Minh',
      'createdByAvatar': 'https://example.com/minh.png',
      'candidateStatus': 'PENDING_REVIEW',
      'placeCheckinCount': 3,
      'recentAvatars': ['https://example.com/an.png'],
      'recentUserNames': ['An', 'Binh'],
    });

    expect(item.address, '12 Nguyen Hue');
    expect(item.visibility, 'FRIENDS');
    expect(item.checkinVisibility, 'FRIENDS');
    expect(item.isCandidate, isTrue);
    expect(item.createdBy, 'user-1');
    expect(item.createdByName, 'Minh');
    expect(item.createdByAvatar, 'https://example.com/minh.png');
    expect(item.candidateStatus, 'PENDING_REVIEW');
    expect(item.placeCheckinCount, 3);
    expect(item.recentAvatars, ['https://example.com/an.png']);
    expect(item.recentUserNames, ['An', 'Binh']);
  });

  test('keeps old map feed payloads valid', () {
    final item = MapFeedItem.fromJson({
      'id': 'checkin-1',
      'caption': 'Nice coffee',
      'createdAt': '2026-06-22T09:00:00.000Z',
      'mediaId': 'media-1',
      'userId': 'friend-1',
      'userName': 'An',
      'placeId': 'place-1',
      'placeName': 'Cafe',
      'category': 'cafe',
      'lat': 10.7738,
      'lng': 106.7035,
    });

    expect(item.address, isNull);
    expect(item.visibility, isNull);
    expect(item.checkinVisibility, isNull);
    expect(item.isCandidate, isFalse);
    expect(item.placeCheckinCount, 1);
    expect(item.recentAvatars, isEmpty);
    expect(item.recentUserNames, isEmpty);
  });
}
