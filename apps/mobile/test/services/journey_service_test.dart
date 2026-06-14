import 'dart:convert';

import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/models/journey_entry.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/journey_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

void main() {
  test('fetches paginated journey reviews', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        '${Config.apiBaseUrl}/journey/reviews?limit=20&cursor=cursor-1',
      );
      expect(request.headers['Authorization'], 'token-123');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'review-1',
              'placeId': 'place-1',
              'placeName': 'AAA Place',
              'content': 'Great',
              'createdAt': '2026-06-10T10:00:00.000Z',
            },
          ],
          'pagination': <String, dynamic>{
            'nextCursor': 'cursor-2',
            'hasMore': true,
          },
        }),
        200,
      );
    });
    final service = JourneyService(
      _FakeAuthService('token-123'),
      client: client,
    );

    final page = await service.fetchReviews(cursor: 'cursor-1');

    expect(page.entries, hasLength(1));
    expect(page.entries.single.type, JourneyEntryType.review);
    expect(page.nextCursor, 'cursor-2');
    expect(page.hasMore, isTrue);
  });

  test('throws when token is missing', () async {
    final service = JourneyService(_FakeAuthService(null));

    await expectLater(
      service.fetchCheckins(),
      throwsA(isA<JourneyException>()),
    );
  });
}
