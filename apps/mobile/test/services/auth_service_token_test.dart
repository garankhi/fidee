import 'dart:convert';

import 'package:fidey_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TokenAuthService extends AuthService {
  _TokenAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

String _jwtWithPayload(Map<String, dynamic> payload) {
  final encodedPayload = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return 'header.$encodedPayload.signature';
}

void main() {
  group('SecureCognitoStorage', () {
    test('clear removes only Cognito keys', () async {
      final values = <String, String>{};
      final storage = SecureCognitoStorage.custom(
        read: (key) async => values[key],
        readAll: () async => Map<String, String>.from(values),
        write: (key, value) async => values[key] = value,
        delete: (key) async => values.remove(key),
      );

      await storage.setItem('CognitoIdentityServiceProvider.client.user', {
        'token': 'jwt',
      });
      await storage.setItem('other', {'keep': true});

      await storage.clear();

      expect(values.keys, ['other']);
    });
  });

  group('AuthService.getCurrentUserSub', () {
    test('returns sub from current JWT payload', () async {
      final service = _TokenAuthService(_jwtWithPayload({'sub': 'user-sub-1'}));

      expect(await service.getCurrentUserSub(), 'user-sub-1');
    });

    test('returns null for malformed or missing tokens', () async {
      expect(await _TokenAuthService(null).getCurrentUserSub(), isNull);
      expect(await _TokenAuthService('not-a-jwt').getCurrentUserSub(), isNull);
      expect(
        await _TokenAuthService(_jwtWithPayload({})).getCurrentUserSub(),
        isNull,
      );
    });
  });

  group('AuthService profile lifecycle', () {
    test('signOut clears in-memory profile details', () async {
      final service = AuthService(isTestMode: true);

      await service.applyProfileDetailsForTesting(<String, dynamic>{
        'displayName': 'Alice Nguyen',
        'username': 'alice',
        'avatarUrl': 'https://cdn.example.com/alice.jpg',
        'plan': 'PRO',
        'createdAt': '2025-05-01T00:00:00.000Z',
      });

      await service.signOut();

      expect(service.state, AuthState.unauthenticated);
      expect(service.firstName, isNull);
      expect(service.lastName, isNull);
      expect(service.preferredUsername, isNull);
      expect(service.avatarUrl, isNull);
      expect(service.since, isNull);
      expect(service.tier, UserTier.free);
    });

    test('applying a new profile clears omitted optional fields', () async {
      final service = AuthService(isTestMode: true);

      await service.applyProfileDetailsForTesting(<String, dynamic>{
        'displayName': 'Alice Nguyen',
        'username': 'alice',
        'avatarUrl': 'https://cdn.example.com/alice.jpg',
        'plan': 'PRO',
        'createdAt': '2025-05-01T00:00:00.000Z',
      });

      await service.applyProfileDetailsForTesting(<String, dynamic>{
        'displayName': 'Bob',
        'plan': 'FREE',
      });

      expect(service.firstName, 'Bob');
      expect(service.lastName, isNull);
      expect(service.preferredUsername, isNull);
      expect(service.avatarUrl, isNull);
      expect(service.since, isNull);
      expect(service.tier, UserTier.free);
    });

    test(
      'requires real first name, last name, and username to be complete',
      () async {
        final service = AuthService(isTestMode: true);

        await service.applyProfileDetailsForTesting(<String, dynamic>{
          'displayName': 'User',
          'plan': 'FREE',
        });
        expect(service.hasCompleteProfileForTesting, isFalse);

        await service.applyProfileDetailsForTesting(<String, dynamic>{
          'displayName': 'Alice',
          'username': 'alice',
          'plan': 'FREE',
        });
        expect(service.hasCompleteProfileForTesting, isFalse);

        await service.applyProfileDetailsForTesting(<String, dynamic>{
          'displayName': 'Alice Nguyen',
          'username': 'alice',
          'plan': 'FREE',
        });
        expect(service.hasCompleteProfileForTesting, isTrue);
      },
    );
  });
}
