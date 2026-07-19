import 'dart:convert';

import 'package:fidey_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _ProfileUpdateAuthService extends AuthService {
  _ProfileUpdateAuthService(http.Client client)
    : super(profileHttpClient: client);

  @override
  Future<String?> getToken() async => 'test-token';
}

Map<String, dynamic> _profileResponse(String avatarUrl) {
  return <String, dynamic>{
    'profile': <String, dynamic>{
      'username': 'alice',
      'avatarUrl': avatarUrl,
      'bio': 'Coffee hunter',
      'plan': 'FREE',
      'createdAt': '2026-01-02T00:00:00.000Z',
    },
  };
}

Future<void> _seedProfile(AuthService service, {required String avatarUrl}) {
  return service.applyProfileDetailsForTesting(<String, dynamic>{
    'displayName': 'Alice Nguyen',
    'username': 'alice',
    'avatarUrl': avatarUrl,
    'bio': 'Coffee hunter',
    'plan': 'FREE',
    'createdAt': '2026-01-02T00:00:00.000Z',
  });
}

void main() {
  group('AuthService profile PATCH', () {
    test('includes the known avatar when saving text fields', () async {
      const avatarUrl = 'https://cdn.example.com/avatars/alice.jpg';
      late Map<String, dynamic> requestBody;
      final service = _ProfileUpdateAuthService(
        MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.headers['authorization'], 'test-token');
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_profileResponse(avatarUrl)), 200);
        }),
      );
      await _seedProfile(service, avatarUrl: avatarUrl);

      final result = await service.updateProfile(
        firstName: 'Alice',
        lastName: 'Updated',
        preferredUsername: 'alice',
        bio: 'Coffee hunter',
      );

      expect(result.success, isTrue);
      expect(requestBody['avatarUrl'], avatarUrl);
      expect(service.avatarUrl, avatarUrl);
    });

    test('persists an avatar-only update through PATCH profile', () async {
      const oldAvatarUrl = 'https://cdn.example.com/avatars/old.jpg';
      const newAvatarUrl = 'https://cdn.example.com/avatars/new.jpg';
      late Map<String, dynamic> requestBody;
      final service = _ProfileUpdateAuthService(
        MockClient((request) async {
          requestBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode(_profileResponse(newAvatarUrl)), 200);
        }),
      );
      await _seedProfile(service, avatarUrl: oldAvatarUrl);

      final result = await service.updateProfile(avatarUrl: newAvatarUrl);

      expect(result.success, isTrue);
      expect(requestBody['firstName'], 'Alice');
      expect(requestBody['lastName'], 'Nguyen');
      expect(requestBody['username'], 'alice');
      expect(requestBody['avatarUrl'], newAvatarUrl);
      expect(service.avatarUrl, newAvatarUrl);
    });
  });
}
