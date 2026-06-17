import 'package:fidee_mobile/config.dart';
import 'package:fidee_mobile/services/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isProEntitlementActive returns true only for pro entitlement', () {
    expect(isProEntitlementActive({'pro'}), isTrue);
    expect(isProEntitlementActive({'Fidee Pro'}), isFalse);
    expect(isProEntitlementActive(<String>{}), isFalse);
  });

  test('subscription product ids are monthly and yearly only', () {
    final productIds = [
      Config.revenueCatMonthlyProductId,
      Config.revenueCatYearlyProductId,
    ];

    expect(productIds, ['fidee_pro_monthly', 'fidee_pro_yearly']);
    expect(productIds, hasLength(2));
  });
}
