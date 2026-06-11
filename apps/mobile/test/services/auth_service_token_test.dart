import 'dart:convert';

import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TokenAuthService extends AuthService {
  _TokenAuthService(this.token) : super(isTestMode: true);

  final String? token;

  @override
  Future<String?> getToken() async => token;
}

String _jwtWithPayload(Map<String, dynamic> payload) {
  final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
  return 'header.$encodedPayload.signature';
}

void main() {
  group('AuthService.getCurrentUserSub', () {
    test('returns sub from current JWT payload', () async {
      final service = _TokenAuthService(_jwtWithPayload({'sub': 'user-sub-1'}));

      expect(await service.getCurrentUserSub(), 'user-sub-1');
    });

    test('returns null for malformed or missing tokens', () async {
      expect(await _TokenAuthService(null).getCurrentUserSub(), isNull);
      expect(await _TokenAuthService('not-a-jwt').getCurrentUserSub(), isNull);
      expect(await _TokenAuthService(_jwtWithPayload({})).getCurrentUserSub(), isNull);
    });
  });
}
