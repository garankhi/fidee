import 'package:fidee_mobile/services/billing_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buildRevenueCatSyncPayload sends Cognito app user id and active entitlements',
    () {
      final payload = buildRevenueCatSyncPayload(
        appUserId: 'user-123',
        activeEntitlementIds: {'pro'},
        productId: 'fidee_pro_monthly',
        store: 'TEST_STORE',
      );

      expect(payload['appUserId'], 'user-123');
      expect(payload['activeEntitlementIds'], ['pro']);
      expect(payload['productId'], 'fidee_pro_monthly');
      expect(payload['store'], 'TEST_STORE');
    },
  );
}
