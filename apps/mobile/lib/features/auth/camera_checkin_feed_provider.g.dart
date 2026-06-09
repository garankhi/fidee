// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'camera_checkin_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cameraCheckinFeedServiceHash() =>
    r'9f613739e3cffcf4a55e42fb6a5ca3a2374f452c';

/// See also [cameraCheckinFeedService].
@ProviderFor(cameraCheckinFeedService)
final cameraCheckinFeedServiceProvider =
    AutoDisposeProvider<CameraCheckinFeedService>.internal(
      cameraCheckinFeedService,
      name: r'cameraCheckinFeedServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cameraCheckinFeedServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CameraCheckinFeedServiceRef =
    AutoDisposeProviderRef<CameraCheckinFeedService>;
String _$cameraCheckinFeedControllerHash() =>
    r'230948325f2983047c01324d21f47e2049290c31';

/// See also [CameraCheckinFeedController].
@ProviderFor(CameraCheckinFeedController)
final cameraCheckinFeedControllerProvider =
    AutoDisposeNotifierProvider<
      CameraCheckinFeedController,
      CameraCheckinFeedState
    >.internal(
      CameraCheckinFeedController.new,
      name: r'cameraCheckinFeedControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$cameraCheckinFeedControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CameraCheckinFeedController =
    AutoDisposeNotifier<CameraCheckinFeedState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
