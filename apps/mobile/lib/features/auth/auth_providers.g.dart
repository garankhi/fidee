// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authServiceHash() => r'd95f6f0327b9783a3e7e039c4caaa93c6a60aa27';

/// See also [authService].
@ProviderFor(authService)
final authServiceProvider = Provider<AuthService>.internal(
  authService,
  name: r'authServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthServiceRef = ProviderRef<AuthService>;
String _$locationControllerHash() =>
    r'ce8d81643511b30466d981a19dbd315d17cf38c8';

/// Khởi động LocationService song song với AuthController ngay từ lúc app start.
/// keepAlive = true → không bị dispose, HomeScreen nhận instance đã sẵn sàng,
/// nhưng chỉ kiểm tra trạng thái quyền; prompt chỉ hiện sau khi user bấm Cho phép.
///
/// Copied from [locationController].
@ProviderFor(locationController)
final locationControllerProvider = FutureProvider<LocationService>.internal(
  locationController,
  name: r'locationControllerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$locationControllerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocationControllerRef = FutureProviderRef<LocationService>;
String _$authControllerHash() => r'111b896c8be5cae0646e61a5824b5ba7ee25dae9';

/// See also [AuthController].
@ProviderFor(AuthController)
final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthUiState>.internal(
      AuthController.new,
      name: r'authControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$authControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AuthController = AsyncNotifier<AuthUiState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
