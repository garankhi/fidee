import 'dart:convert';

import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:fidee_mobile/services/place_candidate_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TokenAuthService extends AuthService {
  _TokenAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

void main() {
  test('createCandidate sends requested visibility', () async {
    final service = PlaceCandidateService(
      _TokenAuthService('token-123'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), '${Config.apiBaseUrl}/place-candidates');
        expect(request.headers['Authorization'], 'token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['visibility'], 'PRIVATE');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 'created',
              'data': {
                'candidate_id': 'candidate-1',
                'name': 'Cafe mới',
                'category': 'cafe',
                'status': 'PENDING_REVIEW',
                'visibility': 'PRIVATE',
                'created_at': '2026-06-16T10:00:00.000Z',
              },
            }),
          ),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.createCandidate(
      name: 'Cafe mới',
      category: 'cafe',
      lat: 10.7,
      lng: 106.6,
      visibility: 'PRIVATE',
    );

    expect(result.isCreated, isTrue);
    expect(result.data?.visibility, 'PRIVATE');
  });

  test('updateCandidate patches candidate details and visibility', () async {
    final service = PlaceCandidateService(
      _TokenAuthService('token-123'),
      client: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(
          request.url.toString(),
          '${Config.apiBaseUrl}/place-candidates/candidate-1',
        );
        expect(request.headers['Authorization'], 'token-123');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['address'], '12 Nguyen Hue');
        expect(body['visibility'], 'PRIVATE');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 'success',
              'data': {
                'id': 'candidate-1',
                'name': 'Cafe mới',
                'address': '12 Nguyen Hue',
                'visibility': 'PRIVATE',
                'status': 'PENDING_REVIEW',
                'updated_at': '2026-06-16T10:00:00.000Z',
              },
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await service.updateCandidate(
      candidateId: 'candidate-1',
      address: '12 Nguyen Hue',
      visibility: 'PRIVATE',
    );

    expect(result['status'], 'success');
    expect((result['data'] as Map<String, dynamic>)['visibility'], 'PRIVATE');
  });
}
