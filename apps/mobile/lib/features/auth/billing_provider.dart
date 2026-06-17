import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../config.dart';
import '../../services/billing_sync_service.dart';
import '../../services/revenuecat_service.dart';

part 'billing_provider.g.dart';

List<String> visibleProPackageIds(List<String> productIds) {
  return productIds
      .where(
        (id) =>
            id == Config.revenueCatMonthlyProductId ||
            id == Config.revenueCatYearlyProductId,
      )
      .toList(growable: false);
}

List<Package> visibleProPackages(Offerings? offerings) {
  final packages = offerings?.current?.availablePackages ?? const <Package>[];
  return packages.where((package) {
    return visibleProPackageIds([package.storeProduct.identifier]).isNotEmpty;
  }).toList(growable: false);
}

void logRevenueCatCustomerInfo(String event, CustomerInfo customerInfo) {
  debugPrint(
    '[RevenueCat] $event originalAppUserId=${customerInfo.originalAppUserId} '
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

  const BillingState({
    required this.isLoading,
    required this.isPurchasing,
    required this.isRestoring,
    this.errorMessage,
    this.customerInfo,
    this.offerings,
  });

  const BillingState.idle()
    : isLoading = false,
      isPurchasing = false,
      isRestoring = false,
      errorMessage = null,
      customerInfo = null,
      offerings = null;

  BillingState copyWith({
    bool? isLoading,
    bool? isPurchasing,
    bool? isRestoring,
    String? errorMessage,
    CustomerInfo? customerInfo,
    Offerings? offerings,
    bool clearError = false,
  }) {
    return BillingState(
      isLoading: isLoading ?? this.isLoading,
      isPurchasing: isPurchasing ?? this.isPurchasing,
      isRestoring: isRestoring ?? this.isRestoring,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      customerInfo: customerInfo ?? this.customerInfo,
      offerings: offerings ?? this.offerings,
    );
  }

  bool get hasPro {
    return customerInfo?.entitlements.active.containsKey(
          Config.revenueCatEntitlementPro,
        ) ??
        false;
  }

  List<Package> get proPackages {
    return visibleProPackages(offerings);
  }
}

@Riverpod(keepAlive: true)
RevenueCatService revenueCatService(RevenueCatServiceRef ref) {
  return const RevenueCatService();
}

@riverpod
class BillingController extends _$BillingController {
  @override
  BillingState build() {
    return const BillingState.idle();
  }

  Future<void> loadCustomerInfo() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final customerInfo = await ref.read(revenueCatServiceProvider).getCustomerInfo();
      logRevenueCatCustomerInfo('loadCustomerInfo', customerInfo);
      state = state.copyWith(isLoading: false, customerInfo: customerInfo);
    } catch (error, stackTrace) {
      debugPrint('[RevenueCat] loadCustomerInfo failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không tải được trạng thái gói Pro',
      );
    }
  }

  Future<void> loadOfferings() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final offerings = await ref.read(revenueCatServiceProvider).getOfferings();
      final packages = offerings.current?.availablePackages ?? const <Package>[];
      debugPrint(
        '[RevenueCat] loadOfferings current=${offerings.current?.identifier} '
        'packages=${packages.map((package) => '${package.identifier}:${package.storeProduct.identifier}').toList()} '
        'visiblePro=${visibleProPackages(offerings).map((package) => package.storeProduct.identifier).toList()}',
      );
      state = state.copyWith(isLoading: false, offerings: offerings);
    } catch (error, stackTrace) {
      debugPrint('[RevenueCat] loadOfferings failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Không tải được lựa chọn gói Pro',
      );
    }
  }

  Future<CustomerInfo?> purchasePackage(
    Package package, {
    String? appUserId,
    BillingSyncService? billingSyncService,
  }) async {
    state = state.copyWith(isPurchasing: true, clearError: true);
    try {
      debugPrint(
        '[RevenueCat] purchase start package=${package.identifier} '
        'product=${package.storeProduct.identifier} appUserId=$appUserId',
      );
      final result = await ref.read(revenueCatServiceProvider).purchase(package);
      final customerInfo = result.customerInfo;
      logRevenueCatCustomerInfo('purchase success', customerInfo);
      await _syncCustomerInfo(
        customerInfo: customerInfo,
        appUserId: appUserId,
        billingSyncService: billingSyncService,
        productId: result.storeTransaction.productIdentifier,
      );
      state = state.copyWith(isPurchasing: false, customerInfo: customerInfo);
      return customerInfo;
    } catch (error, stackTrace) {
      debugPrint('[RevenueCat] purchase failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isPurchasing: false,
        errorMessage: 'Không hoàn tất được thanh toán',
      );
      return null;
    }
  }

  Future<CustomerInfo?> restorePurchases({
    String? appUserId,
    BillingSyncService? billingSyncService,
  }) async {
    state = state.copyWith(isRestoring: true, clearError: true);
    try {
      debugPrint('[RevenueCat] restore start appUserId=$appUserId');
      final customerInfo = await ref.read(revenueCatServiceProvider).restore();
      logRevenueCatCustomerInfo('restore success', customerInfo);
      await _syncCustomerInfo(
        customerInfo: customerInfo,
        appUserId: appUserId,
        billingSyncService: billingSyncService,
      );
      state = state.copyWith(isRestoring: false, customerInfo: customerInfo);
      return customerInfo;
    } catch (error, stackTrace) {
      debugPrint('[RevenueCat] restore failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Không khôi phục được giao dịch',
      );
      return null;
    }
  }

  Future<void> _syncCustomerInfo({
    required CustomerInfo customerInfo,
    required String? appUserId,
    required BillingSyncService? billingSyncService,
    String? productId,
  }) async {
    final trimmedAppUserId = appUserId?.trim();
    if (trimmedAppUserId == null || trimmedAppUserId.isEmpty) {
      debugPrint('[RevenueCat] backend sync skipped: missing appUserId');
      return;
    }
    if (billingSyncService == null) {
      debugPrint('[RevenueCat] backend sync skipped: missing BillingSyncService');
      return;
    }

    try {
      debugPrint(
        '[RevenueCat] backend sync start appUserId=$trimmedAppUserId '
        'activeEntitlements=${customerInfo.entitlements.active.keys.toList()} '
        'productId=$productId',
      );
      await billingSyncService.syncRevenueCat(
        appUserId: trimmedAppUserId,
        activeEntitlementIds: customerInfo.entitlements.active.keys.toSet(),
        productId: productId,
        store: 'TEST_STORE',
      );
      debugPrint('[RevenueCat] backend sync success');
    } catch (error, stackTrace) {
      debugPrint('[RevenueCat] backend sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        errorMessage: 'Thanh toán xong nhưng chưa đồng bộ được gói Pro',
      );
    }
  }
}
