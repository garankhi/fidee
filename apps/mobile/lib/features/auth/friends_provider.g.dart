// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$friendServiceHash() => r'f04872c1f8ef3e4002ecd6d7509392c549edf643';

/// See also [friendService].
@ProviderFor(friendService)
final friendServiceProvider = Provider<FriendService>.internal(
  friendService,
  name: r'friendServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$friendServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FriendServiceRef = ProviderRef<FriendService>;
String _$friendsControllerHash() => r'ded7cf62b6e91dd75a62e2a0e691f3927f71df6c';

/// See also [FriendsController].
@ProviderFor(FriendsController)
final friendsControllerProvider =
    NotifierProvider<FriendsController, FriendsState>.internal(
      FriendsController.new,
      name: r'friendsControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$friendsControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$FriendsController = Notifier<FriendsState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
