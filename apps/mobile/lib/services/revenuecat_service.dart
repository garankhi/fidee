import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

bool isProEntitlementActive(Set<String> activeEntitlementIds) {
  return activeEntitlementIds.contains(Config.revenueCatEntitlementPro);
}

class RevenueCatService {
  const RevenueCatService();

  Future<void> configure() async {
    final apiKey = _apiKeyForPlatform();
    if (apiKey.isEmpty) {
      throw const RevenueCatConfigurationException(
        'RevenueCat API key is missing for this platform',
      );
    }

    debugPrint(
      '[RevenueCat] configure platform=$_platformLabel '
      'key=${_maskApiKey(apiKey)} length=${apiKey.length}',
    );
    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    debugPrint('[RevenueCat] configured appUserId=${await Purchases.appUserID}');
  }

  Future<void> logIn(String appUserId) async {
    final trimmedUserId = appUserId.trim();
    if (trimmedUserId.isEmpty) return;
    debugPrint('[RevenueCat] logIn appUserId=$trimmedUserId');
    final result = await Purchases.logIn(trimmedUserId);
    debugPrint(
      '[RevenueCat] logIn success created=${result.created} '
      'currentAppUserId=${await Purchases.appUserID} '
      'originalAppUserId=${result.customerInfo.originalAppUserId} '
      'activeEntitlements=${result.customerInfo.entitlements.active.keys.toList()} '
      'purchasedProducts=${result.customerInfo.allPurchasedProductIdentifiers}',
    );
  }

  Future<void> logOut() async {
    debugPrint('[RevenueCat] logOut currentAppUserId=${await Purchases.appUserID}');
    await Purchases.logOut();
  }

  Future<CustomerInfo> getCustomerInfo() {
    return Purchases.getCustomerInfo();
  }

  Future<Offerings> getOfferings() {
    return Purchases.getOfferings();
  }

  Future<PurchaseResult> purchase(Package package) {
    return Purchases.purchase(PurchaseParams.package(package));
  }

  Future<CustomerInfo> restore() {
    return Purchases.restorePurchases();
  }

  bool hasPro(CustomerInfo info) {
    return info.entitlements.active.containsKey(Config.revenueCatEntitlementPro);
  }

  String _apiKeyForPlatform() {
    if (Platform.isIOS) return Config.revenueCatIosApiKey;
    if (Platform.isAndroid) return Config.revenueCatAndroidApiKey;
    return '';
  }

  String get _platformLabel {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  String _maskApiKey(String apiKey) {
    if (apiKey.length <= 8) return '${apiKey.substring(0, 2)}***';
    return '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}';
  }
}

class RevenueCatConfigurationException implements Exception {
  final String message;

  const RevenueCatConfigurationException(this.message);

  @override
  String toString() => message;
}
