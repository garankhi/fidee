import 'package:fidey_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('profileUpdateErrorMessage', () {
    test('includes status and message from API Gateway style body', () {
      expect(
        profileUpdateErrorMessage(
          403,
          '{"message":"Missing Authentication Token"}',
        ),
        'Cập nhật profile thất bại (HTTP 403): Missing Authentication Token',
      );
    });

    test('includes status, error, and code from Lambda body', () {
      expect(
        profileUpdateErrorMessage(
          500,
          '{"error":"Internal server error","code":"INTERNAL_ERROR"}',
        ),
        'Cập nhật profile thất bại (HTTP 500): Internal server error [INTERNAL_ERROR]',
      );
    });

    test('falls back to raw non-json body with status', () {
      expect(
        profileUpdateErrorMessage(502, 'Bad Gateway'),
        'Cập nhật profile thất bại (HTTP 502): Bad Gateway',
      );
    });
  });
}
