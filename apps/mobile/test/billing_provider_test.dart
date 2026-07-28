import 'dart:async';

import 'package:fidey_mobile/features/auth/auth_providers.dart';
import 'package:fidey_mobile/features/auth/billing_provider.dart';
import 'package:fidey_mobile/models/pro_access.dart';
import 'package:fidey_mobile/services/auth_service.dart';
import 'package:fidey_mobile/services/billing_sync_service.dart';
import 'package:fidey_mobile/services/revenuecat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class _FailedProfileAuthService extends AuthService {
  _FailedProfileAuthService() : super(isTestMode: true);

  @override
  Future<bool> fetchProfileDetails() async => false;
}

class _DelayedStartupAuthService extends AuthService {
  _DelayedStartupAuthService() : super(isTestMode: true);

  final Completer<String?> userSub = Completer<String?>();

  @override
  AuthState get state => AuthState.authenticated;

  @override
  Future<String?> getCurrentUserSub() => userSub.future;
}

class _SwitchingAuthService extends AuthService {
  _SwitchingAuthService() : super(isTestMode: true);

  AuthState currentState = AuthState.authenticated;
  String? currentUserSub = 'user-a';

  @override
  AuthState get state => currentState;

  @override
  Future<String?> getCurrentUserSub() async => currentUserSub;

  @override
  Future<AuthResult> signIn(String email, String password) async {
    currentState = AuthState.authenticated;
    currentUserSub = null;
    return const AuthResult(success: true);
  }

  @override
  Future<bool> fetchProfileDetails() async => true;
}

class _AuthenticatedProAuthService extends AuthService {
  _AuthenticatedProAuthService() : super(isTestMode: true);

  bool _profileFetched = false;

  @override
  AuthState get state => AuthState.authenticated;

  @override
  UserTier get tier => _profileFetched ? UserTier.pro : UserTier.free;

  @override
  Future<AuthResult> signIn(String email, String password) async {
    return const AuthResult(success: true);
  }

  @override
  Future<bool> fetchProfileDetails() async {
    _profileFetched = true;
    return true;
  }
}

class _FakeBillingSyncService extends BillingSyncService {
  final Future<BillingSyncResult> Function() result;

  _FakeBillingSyncService(this.result)
    : super(authService: AuthService(isTestMode: true));

  @override
  Future<BillingSyncResult> syncRevenueCat() => result();
}

const _billingCustomerInfo = CustomerInfo(
  EntitlementInfos({}, {}),
  {},
  [],
  [],
  [],
  '2026-07-28T00:00:00Z',
  'user-a',
  {},
  '2026-07-28T00:00:00Z',
);

void main() {
  test('pro packages only expose monthly and yearly options', () {
    final packages = visibleProPackageIds([
      'fidee_pro_monthly',
      'fidee_pro_yearly',
      'fidee_pro_legacy',
    ]);

    expect(packages, ['fidee_pro_monthly', 'fidee_pro_yearly']);
  });

  test('pro packages match Google Play base-plan suffix identifiers', () {
    final packages = visibleProPackageIds([
      'fidee_pro_monthly:monthly',
      'fidee_pro_yearly:yearly',
      'fidee_pro_legacy:legacy',
    ]);

    expect(packages, ['fidee_pro_monthly:monthly', 'fidee_pro_yearly:yearly']);
  });

  test('billing state starts idle', () {
    const state = BillingState.idle();
    expect(state.isLoading, isFalse);
    expect(state.isPurchasing, isFalse);
    expect(state.isRestoring, isFalse);
    expect(state.errorMessage, isNull);
  });

  test('confirmed plan remains independent from sync status', () {
    final freeReconciling = const BillingState.idle().copyWith(
      confirmedPlan: ConfirmedProPlan.free,
      syncStatus: BillingSyncStatus.reconciling,
    );
    final proFailed = const BillingState.idle().copyWith(
      confirmedPlan: ConfirmedProPlan.pro,
      syncStatus: BillingSyncStatus.failed,
    );

    expect(freeReconciling.hasPro, isFalse);
    expect(proFailed.hasPro, isTrue);
  });

  test('controller seeds plan from backend profile tier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(billingControllerProvider, (_, _) {});

    container
        .read(billingControllerProvider.notifier)
        .seedConfirmedPlan(UserTier.pro);

    expect(
      container.read(billingControllerProvider).confirmedPlan,
      ConfirmedProPlan.pro,
    );
  });

  test('authenticated startup does not await billing identity lookup', () async {
    final service = _DelayedStartupAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    addTearDown(() {
      if (!service.userSub.isCompleted) service.userSub.complete(null);
    });
    container.listen(authControllerProvider, (_, _) {});

    final initialState = await container
        .read(authControllerProvider.future)
        .timeout(const Duration(milliseconds: 100));

    expect(initialState.authState, AuthState.authenticated);
  });

  test('a prior account login cannot reconcile after account switch', () async {
    final authService = _SwitchingAuthService();
    final loginStarted = Completer<void>();
    final releaseLogin = Completer<void>();
    final revenueCatService = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {},
      logInSdk: (appUserId) async {
        if (appUserId == 'user-a') {
          loginStarted.complete();
          await releaseLogin.future;
        }
        return LogInResult(
          created: false,
          customerInfo: _billingCustomerInfo,
        );
      },
      logOutSdk: () async {},
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        revenueCatServiceProvider.overrideWithValue(revenueCatService),
      ],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    await loginStarted.future;

    await container
        .read(authControllerProvider.notifier)
        .signIn('bob@example.com', 'password');
    releaseLogin.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      container.read(billingControllerProvider).syncStatus,
      BillingSyncStatus.idle,
    );
  });

  test('successful sign-in seeds the authoritative profile plan', () async {
    final service = _AuthenticatedProAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);

    await container
        .read(authControllerProvider.notifier)
        .signIn('alice@example.com', 'password');

    expect(
      container.read(billingControllerProvider).confirmedPlan,
      ConfirmedProPlan.pro,
    );
  });

  test('failed profile refresh preserves the last confirmed plan', () async {
    final service = _FailedProfileAuthService();
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
    container
        .read(billingControllerProvider.notifier)
        .seedConfirmedPlan(UserTier.pro);

    await container
        .read(authControllerProvider.notifier)
        .refreshProfileDetails();

    expect(
      container.read(billingControllerProvider).confirmedPlan,
      ConfirmedProPlan.pro,
    );
  });

  test('successful reconciliation updates backend-confirmed plan', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(billingControllerProvider, (_, _) {});
    final result = BillingSyncResult(
      plan: ConfirmedProPlan.pro,
      entitlement: 'pro',
      reconciledAt: DateTime.utc(2026, 7, 28),
    );

    final reconciled = await container
        .read(billingControllerProvider.notifier)
        .reconcile(_FakeBillingSyncService(() async => result));

    expect(reconciled, same(result));
    expect(container.read(billingControllerProvider).hasPro, isTrue);
    expect(
      container.read(billingControllerProvider).syncStatus,
      BillingSyncStatus.idle,
    );
  });

  test('failed reconciliation preserves the last confirmed plan', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(billingControllerProvider, (_, _) {});
    final controller = container.read(billingControllerProvider.notifier);
    controller.seedConfirmedPlan(UserTier.pro);

    final reconciled = await controller.reconcile(
      _FakeBillingSyncService(
        () async => throw const BillingSyncException('network'),
      ),
    );

    expect(reconciled, isNull);
    expect(container.read(billingControllerProvider).hasPro, isTrue);
    expect(
      container.read(billingControllerProvider).syncStatus,
      BillingSyncStatus.failed,
    );
  });

  test('sign out resets all account-scoped billing state', () async {
    final service = AuthService(isTestMode: true);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);

    final billing = container.read(billingControllerProvider.notifier);
    billing.seedConfirmedPlan(UserTier.pro);
    await billing.reconcile(
      _FakeBillingSyncService(
        () async => throw const BillingSyncException('network'),
      ),
    );

    await container.read(authControllerProvider.notifier).signOut();

    final state = container.read(billingControllerProvider);
    expect(state.confirmedPlan, ConfirmedProPlan.free);
    expect(state.syncStatus, BillingSyncStatus.idle);
    expect(state.activationStatus, BillingActivationStatus.none);
    expect(state.syncMessage, isNull);
    expect(state.errorMessage, isNull);
    expect(state.customerInfo, isNull);
  });

  test('account deletion resets all account-scoped billing state', () async {
    final service = AuthService(isTestMode: true);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);

    final billing = container.read(billingControllerProvider.notifier);
    billing.seedConfirmedPlan(UserTier.pro);
    await billing.reconcile(
      _FakeBillingSyncService(
        () async => throw const BillingSyncException('network'),
      ),
    );

    final result = await container
        .read(authControllerProvider.notifier)
        .deleteAccount();

    expect(result.success, isTrue);
    final state = container.read(billingControllerProvider);
    expect(state.confirmedPlan, ConfirmedProPlan.free);
    expect(state.syncStatus, BillingSyncStatus.idle);
    expect(state.syncMessage, isNull);
  });

  test('sign out invalidates an in-flight reconciliation result', () async {
    final service = AuthService(isTestMode: true);
    final container = ProviderContainer(
      overrides: [authServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.listen(authControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);

    final result = BillingSyncResult(
      plan: ConfirmedProPlan.pro,
      entitlement: 'pro',
      reconciledAt: DateTime.utc(2026, 7, 28),
    );
    final completer = Completer<BillingSyncResult>();
    final reconciliation = container
        .read(billingControllerProvider.notifier)
        .reconcile(_FakeBillingSyncService(() => completer.future));
    await Future<void>.delayed(Duration.zero);

    await container.read(authControllerProvider.notifier).signOut();
    completer.complete(result);

    expect(await reconciliation, isNull);
    final state = container.read(billingControllerProvider);
    expect(state.confirmedPlan, ConfirmedProPlan.free);
    expect(state.syncStatus, BillingSyncStatus.idle);
  });

  test('account reset invalidates an in-flight restore result', () async {
    final restoreCompleter = Completer<CustomerInfo>();
    final revenueCatService = RevenueCatService(
      apiKeyProvider: () => 'test-api-key',
      configureSdk: (_) async {},
      restoreSdk: () => restoreCompleter.future,
    );
    final container = ProviderContainer(
      overrides: [
        revenueCatServiceProvider.overrideWithValue(revenueCatService),
      ],
    );
    addTearDown(container.dispose);
    container.listen(billingControllerProvider, (_, _) {});

    final controller = container.read(billingControllerProvider.notifier);
    final restore = controller.restorePurchases();
    await Future<void>.delayed(Duration.zero);

    controller.resetForAccountChange();
    restoreCompleter.complete(_billingCustomerInfo);

    expect(await restore, BillingPurchaseOutcome.failed);
    final state = container.read(billingControllerProvider);
    expect(state.customerInfo, isNull);
    expect(state.activationStatus, BillingActivationStatus.none);
    expect(state.isRestoring, isFalse);
  });

  test(
    'RevenueCat login bridge requires authenticated user and app user id',
    () {
      expect(
        shouldLogInRevenueCat(
          const AuthUiState(authState: AuthState.authenticated),
          ' user-123 ',
        ),
        isTrue,
      );
      expect(
        shouldLogInRevenueCat(
          const AuthUiState(authState: AuthState.incompleteProfile),
          'user-123',
        ),
        isTrue,
      );
      expect(
        shouldLogInRevenueCat(
          const AuthUiState(authState: AuthState.unauthenticated),
          'user-123',
        ),
        isFalse,
      );
      expect(
        shouldLogInRevenueCat(
          const AuthUiState(authState: AuthState.authenticated),
          '   ',
        ),
        isFalse,
      );
    },
  );
}
