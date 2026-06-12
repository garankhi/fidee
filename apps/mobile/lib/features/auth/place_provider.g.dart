// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'place_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$placeControllerHash() => r'99c08f29d2c2998560396a43992e963a70af246b';

/// See also [PlaceController].
@ProviderFor(PlaceController)
final placeControllerProvider =
    AutoDisposeNotifierProvider<PlaceController, Place>.internal(
      PlaceController.new,
      name: r'placeControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$placeControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaceController = AutoDisposeNotifier<Place>;
String _$placeFeedControllerHash() =>
    r'd8f3d42daf86e4048d9e4cc16b8714c1cb616951';

/// See also [PlaceFeedController].
@ProviderFor(PlaceFeedController)
final placeFeedControllerProvider =
    AutoDisposeAsyncNotifierProvider<PlaceFeedController, List<Place>>.internal(
      PlaceFeedController.new,
      name: r'placeFeedControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$placeFeedControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PlaceFeedController = AutoDisposeAsyncNotifier<List<Place>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
