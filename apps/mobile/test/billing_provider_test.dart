import 'package:fidee_mobile/features/auth/auth_providers.dart';
import 'package:fidee_mobile/features/auth/billing_provider.dart';
import 'package:fidee_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pro packages only expose monthly and yearly options', () {
    final packages = visibleProPackageIds([
      'fidee_pro_monthly',
      'fidee_pro_yearly',
      'fidee_pro_legacy',
    ]);

    expect(packages, ['fidee_pro_monthly', 'fidee_pro_yearly']);
  });

  test('billing state starts idle', () {
    const state = BillingState.idle();
    expect(state.isLoading, isFalse);
    expect(state.isPurchasing, isFalse);
    expect(state.isRestoring, isFalse);
    expect(state.errorMessage, isNull);
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
