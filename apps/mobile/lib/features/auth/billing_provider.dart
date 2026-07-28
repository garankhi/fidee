import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config.dart';
import '../../models/pro_access.dart';
import '../../services/auth_service.dart';
import '../../services/billing_sync_service.dart';
import '../../services/revenuecat_service.dart';

part 'billing_provider.g.dart';

bool matchesProProductId(String identifier, String productId) {
  if (identifier == productId) return true;
  return identifier.startsWith('$productId:');
}

List<String> visibleProPackageIds(List<String> productIds) {
  return productIds
      .where(
        (id) =>
            matchesProProductId(id, Config.revenueCatMonthlyProductId) ||
            matchesProProductId(id, Config.revenueCatYearlyProductId),
      )
      .toList(growable: false);
}

List<Package> visibleProPackages(Offerings? offerings) {
  final packages = offerings?.current?.availablePackages ?? const <Package>[];
  return packages
      .where((package) {
        return visibleProPackageIds([
          package.storeProduct.identifier,
        ]).isNotEmpty;
      })
      .toList(growable: false);
}

void logRevenueCatCustomerInfo(String event, CustomerInfo customerInfo) {
  if (!kDebugMode) return;

  debugPrint(
    '[RevenueCat] $event '
    'activeEntitlements=${customerInfo.entitlements.active.keys.toList()} '
    'allPurchasedProducts=${customerInfo.allPurchasedProductIdentifiers} '
    'latestExpirationDate=${customerInfo.latestExpirationDate}',
  );
}

class BillingState {
  final bool isLoading;
  final bool isPurchasing;
  final bool isRestoring;
  final String? errorMessage;
  final CustomerInfo? customerInfo;
  final Offerings? offerings;
  final ConfirmedProPlan confirmedPlan;
  final BillingSyncStatus syncStatus;
  final BillingActivationStatus activationStatus;
  final String? syncMessage;

  const BillingState({
    required this.isLoading,
    required this.isPurchasing,
    required this.isRestoring,
    required this.confirmedPlan,
    required this.syncStatus,
    required this.activationStatus,
    this.errorMessage,
    this.customerInfo,
    this.offerings,
    this.syncMessage,
  });

  const BillingState.idle()
    : isLoading = false,
      isPurchasing = false,
      isRestoring = false,
      confirmedPlan = ConfirmedProPlan.free,
      syncStatus = BillingSyncStatus.idle,
      activationStatus = BillingActivationStatus.none,
      errorMessage = null,
      customerInfo = null,
      offerings = null,
      syncMessage = null;

  BillingState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? isRestoring,
    String? errorMessage,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    ConfirmedProPlan? confirmedPlan,
    BillingSyncStatus? syncStatus,
    BillingActivationStatus? activationStatus,
    String? syncMessage,
    bool clearError = false,
    bool clearSyncMessage = false,
  }) {
    return BillingState(
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      confirmedPlan: confirmedPlan ?? this.confirmedPlan,
      syncStatus: syncStatus ?? this.syncStatus,
      activationStatus: activationStatus ?? this.activationStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
      syncMessage: clearSyncMessage ? null : syncMessage ?? this.syncMessage,
    );
  }

  bool get hasPro => confirmedPlan == ConfirmedProPlan.pro;

  List<Package> get proPackages {
    return visibleProPackages(offerings);
  }
}

@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(RevenueCatServiceRef ref) {
  return RevenueCatService();
}

@Riverpod(keepAlive: true)
class BillingController extends _$BillingController {
  int _accountRevision = 0;

  @override
  BillingState build() {
    return const BillingState.idle();
  }

  void resetForAccountChange() {
    _accountRevision += 1;
    state = const BillingState.idle();
  }

  void seedConfirmedPlan(UserTier tier) {
    state = state.copyWith(
      confirmedPlan: tier == UserTier.pro
          ? ConfirmedProPlan.pro
          : ConfirmedProPlan.free,
      activationStatus: tier == UserTier.pro
          ? BillingActivationStatus.none
          : state.activationStatus,
    );
  }

  Future<BillingSyncResult?> reconcile(
    BillingSyncService billingSyncService,
  ) async {
    final accountRevision = _accountRevision;
    state = state.copyWith(
      syncStatus: BillingSyncStatus.reconciling,
      clearSyncMessage: true,
      clearError: true,
    );
    try {
      final result = await billingSyncService.syncRevenueCat();
      if (accountRevision != _accountRevision) return null;

      final hasPendingActivation =
          state.activationStatus != BillingActivationStatus.none;
      state = state.copyWith(
        confirmedPlan: result.plan,
        syncStatus: BillingSyncStatus.idle,
        activationStatus: result.plan == ConfirmedProPlan.pro
            ? BillingActivationStatus.none
            : hasPendingActivation
            ? BillingActivationStatus.failed
            : BillingActivationStatus.none,
        clearSyncMessage: true,
      );
      return result;
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) return null;

      if (kDebugMode) {
        debugPrint('[RevenueCat] backend reconciliation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      state = state.copyWith(
        syncStatus: BillingSyncStatus.failed,
        activationStatus: state.activationStatus == BillingActivationStatus.none
            ? BillingActivationStatus.none
            : BillingActivationStatus.failed,
        syncMessage: 'Không đồng bộ được gói Pro. Vui lòng thử lại.',
      );
      return null;
    }
  }

  Future<void> loadCustomerInfo() async {
    final accountRevision = _accountRevision;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final customerInfo = await ref
          .read(revenueCatServiceProvider)
          .getCustomerInfo();
      if (accountRevision != _accountRevision) return;

      logRevenueCatCustomerInfo('loadCustomerInfo', customerInfo);
      state = state.copyWith(isLoading: false, customerInfo: customerInfo);
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) return;

      if (kDebugMode) {
        debugPrint('[RevenueCat] loadCustomerInfo failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không tải được trạng thái gói Pro',
      );
    }
  }

  Future<void> loadOfferings() async {
    final accountRevision = _accountRevision;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offerings = await ref
          .read(revenueCatServiceProvider)
          .getOfferings();
      if (accountRevision != _accountRevision) return;

      state = state.copyWith(isLoading: false, offerings: offerings);
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) return;

      if (kDebugMode) {
        debugPrint('[RevenueCat] loadOfferings failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không tải được lựa chọn gói Pro',
      );
    }
  }

  Future<BillingPurchaseOutcome> purchasePackage(Package package) async {
    final accountRevision = _accountRevision;
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      final result = await ref
          .read(revenueCatServiceProvider)
          .purchase(package);
      if (accountRevision != _accountRevision) {
        return BillingPurchaseOutcome.failed;
      }

      logRevenueCatCustomerInfo('purchase success', result.customerInfo);
      state = state.copyWith(
        isPurchasing: false,
        customerInfo: result.customerInfo,
        activationStatus: BillingActivationStatus.pending,
      );
      return BillingPurchaseOutcome.purchased;
    } on PlatformException catch (error, stackTrace) {
      if (accountRevision != _accountRevision) {
        return BillingPurchaseOutcome.failed;
      }

      final errorCode = PurchasesErrorHelper.getErrorCode(error);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        state = state.copyWith(isPurchasing: false, clearError: true);
        return BillingPurchaseOutcome.cancelled;
      }
      if (errorCode == PurchasesErrorCode.productAlreadyPurchasedError) {
        await _recoverAlreadyOwnedCustomerInfo(accountRevision);
        if (accountRevision != _accountRevision) {
          return BillingPurchaseOutcome.failed;
        }
        state = state.copyWith(
          isPurchasing: false,
          activationStatus: BillingActivationStatus.pending,
          clearError: true,
        );
        return BillingPurchaseOutcome.alreadyOwned;
      }
      _recordPurchaseFailure(error, stackTrace);
      return BillingPurchaseOutcome.failed;
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) {
        return BillingPurchaseOutcome.failed;
      }
      _recordPurchaseFailure(error, stackTrace);
      return BillingPurchaseOutcome.failed;
    }
  }

  Future<BillingPurchaseOutcome> restorePurchases() async {
    final accountRevision = _accountRevision;
    state = state.copyWith(isRestoring: true, clearError: true);
    try {
      final customerInfo = await ref.read(revenueCatServiceProvider).restore();
      if (accountRevision != _accountRevision) {
        return BillingPurchaseOutcome.failed;
      }

      logRevenueCatCustomerInfo('restore success', customerInfo);
      state = state.copyWith(
        isRestoring: false,
        customerInfo: customerInfo,
        activationStatus: BillingActivationStatus.pending,
      );
      return BillingPurchaseOutcome.alreadyOwned;
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) {
        return BillingPurchaseOutcome.failed;
      }

      if (kDebugMode) {
        debugPrint('[RevenueCat] restore failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Không khôi phục được giao dịch',
      );
      return BillingPurchaseOutcome.failed;
    }
  }

  Future<void> _recoverAlreadyOwnedCustomerInfo(
    int accountRevision,
  ) async {
    try {
      final customerInfo = await ref
          .read(revenueCatServiceProvider)
          .getCustomerInfo();
      if (accountRevision != _accountRevision) return;

      logRevenueCatCustomerInfo('already owned recovery', customerInfo);
      state = state.copyWith(customerInfo: customerInfo);
    } catch (error, stackTrace) {
      if (accountRevision != _accountRevision) return;

      if (kDebugMode) {
        debugPrint('[RevenueCat] already owned recovery failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void _recordPurchaseFailure(Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('[RevenueCat] purchase failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    state = state.copyWith(
      isPurchasing: false,
      errorMessage: 'Không hoàn tất được thanh toán',
    );
  }
}
