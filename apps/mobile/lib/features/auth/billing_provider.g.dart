// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$revenueCatServiceHash() => r'd00ff19577a3b0d873e7c43ea1d62f08589c3afa';

/// See also [revenueCatService].
@ProviderFor(revenueCatService)
final revenueCatServiceProvider = Provider<RevenueCatService>.internal(
  revenueCatService,
  name: r'revenueCatServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$revenueCatServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RevenueCatServiceRef = ProviderRef<RevenueCatService>;
String _$billingControllerHash() => r'7586365efb9b84dd5d2c735d7c74254424d7f4f6';

/// See also [BillingController].
@ProviderFor(BillingController)
final billingControllerProvider =
    NotifierProvider<BillingController, BillingState>.internal(
      BillingController.new,
      name: r'billingControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$billingControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BillingController = Notifier<BillingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
