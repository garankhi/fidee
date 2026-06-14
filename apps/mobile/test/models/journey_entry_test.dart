import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/models/journey_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a journey review and resolves media URL', () {
    final entry = JourneyEntry.fromJson(
      const <String, dynamic>{
        'id': 'review-1',
        'placeId': 'place-1',
        'placeName': 'AAA Place',
        'rating': 4,
        'content': 'Great food',
        'coverMediaId': 'media-1',
        'createdAt': '2026-06-10T10:00:00.000Z',
        'friendsSavedCount': 5,
      },
      type: JourneyEntryType.review,
    );

    expect(entry.text, 'Great food');
    expect(entry.rating, 4);
    expect(entry.imageUrl, '${Config.apiBaseUrl}/media/media-1');
    expect(entry.friendsSavedCount, 5);
  });

  test('uses caption and absolute image URL for check-in', () {
    final entry = JourneyEntry.fromJson(
      const <String, dynamic>{
        'id': 'checkin-1',
        'placeId': 'place-1',
        'placeName': 'AAA Place',
        'caption': 'Lunch',
        'mediaId': 'https://cdn.example.com/checkin.jpg',
        'createdAt': '2026-06-10T10:00:00.000Z',
      },
      type: JourneyEntryType.checkin,
    );

    expect(entry.text, 'Lunch');
    expect(entry.imageUrl, 'https://cdn.example.com/checkin.jpg');
  });
}
