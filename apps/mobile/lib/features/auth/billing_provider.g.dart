// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'billing_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$revenueCatServiceHash() => r'af43cc7353762607cbdb02a6c6ea236686e6dc7b';

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
String _$billingControllerHash() => r'f05e3248c16a1db20f05a8f78767ed957b539c48';

/// See also [BillingController].
@ProviderFor(BillingController)
final billingControllerProvider =
    AutoDisposeNotifierProvider<BillingController, BillingState>.internal(
      BillingController.new,
      name: r'billingControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$billingControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BillingController = AutoDisposeNotifier<BillingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
