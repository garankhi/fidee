import 'dart:async';

import 'package:fidey_mobile/config.dart';
import 'package:fidey_mobile/services/revenuecat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _customerInfo = CustomerInfo(
  EntitlementInfos({}, {}),
  {},
  [],
  [],
  [],
  '2026-07-28T00:00:00Z',
  'user-123',
  {},
  '2026-07-28T00:00:00Z',
);

void main() {
  test('isProEntitlementActive returns true only for pro entitlement', () {
    expect(isProEntitlementActive({'pro'}), isTrue);
    expect(isProEntitlementActive({'Fidey Pro'}), isFalse);
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

  test('parallel operations configure the SDK once', () async {
    var configureCalls = 0;
    final service = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {
        configureCalls += 1;
        await Future<void>.delayed(Duration.zero);
      },
      logInSdk: (_) async =>
          LogInResult(created: false, customerInfo: _customerInfo),
      getOfferingsSdk: () async => const Offerings({}),
    );

    final results = await Future.wait<Object?>([
      service.logIn('user-123'),
      service.getOfferings(),
    ]);

    expect(configureCalls, 1);
    expect(results.first, same(_customerInfo));
  });

  test('serializes RevenueCat login and logout identity changes', () async {
    final events = <String>[];
    final loginCompleter = Completer<LogInResult>();
    final service = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {},
      logInSdk: (_) async {
        events.add('login-start');
        final result = await loginCompleter.future;
        events.add('login-complete');
        return result;
      },
      logOutSdk: () async {
        events.add('logout');
      },
    );

    final login = service.logIn('user-a');
    await Future<void>.delayed(Duration.zero);
    final logout = service.logOut();
    await Future<void>.delayed(Duration.zero);
    loginCompleter.complete(
      LogInResult(created: false, customerInfo: _customerInfo),
    );
    await Future.wait<Object?>([login, logout]);

    expect(events, ['login-start', 'login-complete', 'logout']);
  });

  test('customer info waits for an in-flight RevenueCat login', () async {
    final events = <String>[];
    final loginCompleter = Completer<LogInResult>();
    final service = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {},
      logInSdk: (_) async {
        events.add('login-start');
        final result = await loginCompleter.future;
        events.add('login-complete');
        return result;
      },
      getCustomerInfoSdk: () async {
        events.add('customer-info');
        return _customerInfo;
      },
    );

    final login = service.logIn('user-a');
    await Future<void>.delayed(Duration.zero);
    final customerInfo = service.getCustomerInfo();
    await Future<void>.delayed(Duration.zero);

    expect(events, ['login-start']);

    loginCompleter.complete(
      LogInResult(created: false, customerInfo: _customerInfo),
    );
    await Future.wait<Object?>([login, customerInfo]);

    expect(events, ['login-start', 'login-complete', 'customer-info']);
  });

  test('login returns RevenueCat CustomerInfo for recovery evidence', () async {
    final service = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {},
      logInSdk: (_) async =>
          LogInResult(created: false, customerInfo: _customerInfo),
    );

    expect(await service.logIn(' user-123 '), same(_customerInfo));
  });
}
