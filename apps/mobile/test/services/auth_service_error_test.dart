import 'package:fidey_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  group('googleSignInErrorMessage', () {
    test('treats plain deliberate cancellation as silent', () {
      expect(
        googleSignInErrorMessage(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
        isNull,
      );
    });

    test('maps account reauthentication failure to retry guidance', () {
      expect(
        googleSignInErrorMessage(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: '[16] Account reauth failed',
          ),
        ),
        contains('thử lại'),
      );
    });

    test('maps client configuration separately', () {
      expect(
        googleSignInErrorMessage(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'OAuth client mismatch',
          ),
        ),
        contains('cấu hình Google'),
      );
    });

    test('maps interrupted, unavailable, and unknown errors safely', () {
      for (final code in [
        GoogleSignInExceptionCode.interrupted,
        GoogleSignInExceptionCode.uiUnavailable,
        GoogleSignInExceptionCode.unknownError,
        GoogleSignInExceptionCode.userMismatch,
      ]) {
        expect(
          googleSignInErrorMessage(GoogleSignInException(code: code)),
          contains('thử lại'),
        );
      }
    });
  });

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
