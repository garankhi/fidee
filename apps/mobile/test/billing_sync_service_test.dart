import 'package:fidey_mobile/models/pro_access.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/billing_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AuthService extends AuthService {
  _AuthService() : super(isTestMode: true);

  @override
  Future<String?> getToken() async => 'token';
}

void main() {
  test('buildRevenueCatSyncPayload sends no client entitlement evidence', () {
    expect(buildRevenueCatSyncPayload(), <String, dynamic>{});
  });

  test('syncRevenueCat parses the backend-confirmed PRO plan', () async {
    late http.Request request;
    final service = BillingSyncService(
      authService: _AuthService(),
      client: MockClient((value) async {
        request = value;
        return http.Response(
          '{"plan":"PRO","entitlement":"pro","reconciledAt":"2026-07-28T10:00:00.000Z"}',
          200,
        );
      }),
    );

    final result = await service.syncRevenueCat();

    expect(request.body, '{}');
    expect(result.plan, ConfirmedProPlan.pro);
    expect(result.entitlement, 'pro');
    expect(result.reconciledAt, DateTime.parse('2026-07-28T10:00:00.000Z'));
  });

  test('syncRevenueCat rejects malformed success responses', () async {
    final service = BillingSyncService(
      authService: _AuthService(),
      client: MockClient((_) async => http.Response('{"plan":"PRO"}', 200)),
    );

    await expectLater(
      service.syncRevenueCat(),
      throwsA(isA<BillingSyncException>()),
    );
  });
}
