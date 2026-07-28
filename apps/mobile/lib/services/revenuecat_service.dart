import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

bool isProEntitlementActive(Set<String> activeEntitlementIds) {
  return activeEntitlementIds.contains(Config.revenueCatEntitlementPro);
}

typedef RevenueCatConfigureSdk = Future<void> Function(String apiKey);
typedef RevenueCatLogInSdk = Future<LogInResult> Function(String appUserId);
typedef RevenueCatLogOutSdk = Future<void> Function();
typedef RevenueCatCustomerInfoSdk = Future<CustomerInfo> Function();
typedef RevenueCatOfferingsSdk = Future<Offerings> Function();
typedef RevenueCatPurchaseSdk =
    Future<PurchaseResult> Function(Package package);

class RevenueCatService {
  final String Function() _apiKeyProvider;
  final RevenueCatConfigureSdk _configureSdk;
  final RevenueCatLogInSdk _logInSdk;
  final RevenueCatLogOutSdk _logOutSdk;
  final RevenueCatCustomerInfoSdk _getCustomerInfoSdk;
  final RevenueCatOfferingsSdk _getOfferingsSdk;
  final RevenueCatPurchaseSdk _purchaseSdk;
  final RevenueCatCustomerInfoSdk _restoreSdk;

  Future<void>? _configurationFuture;
  Future<void> _sdkOperationTail = Future<void>.value();

  RevenueCatService({
    String Function()? apiKeyProvider,
    RevenueCatConfigureSdk? configureSdk,
    RevenueCatLogInSdk? logInSdk,
    RevenueCatLogOutSdk? logOutSdk,
    RevenueCatCustomerInfoSdk? getCustomerInfoSdk,
    RevenueCatOfferingsSdk? getOfferingsSdk,
    RevenueCatPurchaseSdk? purchaseSdk,
    RevenueCatCustomerInfoSdk? restoreSdk,
  }) : _apiKeyProvider = apiKeyProvider ?? _defaultApiKeyForPlatform,
       _configureSdk = configureSdk ?? _defaultConfigureSdk,
       _logInSdk = logInSdk ?? Purchases.logIn,
       _logOutSdk = logOutSdk ?? Purchases.logOut,
       _getCustomerInfoSdk = getCustomerInfoSdk ?? Purchases.getCustomerInfo,
       _getOfferingsSdk = getOfferingsSdk ?? Purchases.getOfferings,
       _purchaseSdk =
           purchaseSdk ??
           ((package) => Purchases.purchase(PurchaseParams.package(package))),
       _restoreSdk = restoreSdk ?? Purchases.restorePurchases;

  Future<void> ensureConfigured() {
    return _configurationFuture ??= _configureOnce();
  }

  Future<void> _configureOnce() async {
    final apiKey = _apiKeyProvider();
    if (apiKey.isEmpty) {
      throw const RevenueCatConfigurationException(
        'RevenueCat API key is missing for this platform',
      );
    }

    if (kDebugMode) {
      debugPrint(
        '[RevenueCat] configure platform=$_platformLabel '
        'key=${_maskApiKey(apiKey)} length=${apiKey.length}',
      );
    }
    await _configureSdk(apiKey);
  }

  Future<CustomerInfo?> logIn(String appUserId) {
    final trimmedUserId = appUserId.trim();
    if (trimmedUserId.isEmpty) return Future<CustomerInfo?>.value();

    return _serializeSdkOperation(() async {
      await ensureConfigured();
      if (kDebugMode) {
        debugPrint('[RevenueCat] logIn appUserId=$trimmedUserId');
      }
      final result = await _logInSdk(trimmedUserId);
      if (kDebugMode) {
        debugPrint(
          '[RevenueCat] logIn success created=${result.created} '
          'originalAppUserId=${result.customerInfo.originalAppUserId} '
          'activeEntitlements=${result.customerInfo.entitlements.active.keys.toList()} '
          'purchasedProducts=${result.customerInfo.allPurchasedProductIdentifiers}',
        );
      }
      return result.customerInfo;
    });
  }

  Future<void> logOut() {
    return _serializeSdkOperation(() async {
      await ensureConfigured();
      await _logOutSdk();
    });
  }

  Future<T> _serializeSdkOperation<T>(Future<T> Function() operation) {
    final result = _sdkOperationTail.then((_) => operation());
    _sdkOperationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<CustomerInfo> getCustomerInfo() {
    return _serializeSdkOperation(() async {
      await ensureConfigured();
      return _getCustomerInfoSdk();
    });
  }

  Future<Offerings> getOfferings() {
    return _serializeSdkOperation(() async {
      await ensureConfigured();
      return _getOfferingsSdk();
    });
  }

  Future<PurchaseResult> purchase(Package package) {
    return _serializeSdkOperation(() async {
      await ensureConfigured();
      return _purchaseSdk(package);
    });
  }

  Future<CustomerInfo> restore() {
    return _serializeSdkOperation(() async {
      await ensureConfigured();
      return _restoreSdk();
    });
  }

  bool hasPro(CustomerInfo info) {
    return info.entitlements.active.containsKey(
      Config.revenueCatEntitlementPro,
    );
  }

  static String _defaultApiKeyForPlatform() {
    if (Platform.isIOS) return Config.revenueCatIosApiKey;
    if (Platform.isAndroid) return Config.revenueCatAndroidApiKey;
    return '';
  }

  static Future<void> _defaultConfigureSdk(String apiKey) async {
    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
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
