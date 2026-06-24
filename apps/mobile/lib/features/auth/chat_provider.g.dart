// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userChatServiceHash() => r'f9c79deab93ed8a77f748abc318782e07e8fdb9f';

/// See also [userChatService].
@ProviderFor(userChatService)
final userChatServiceProvider = Provider<UserChatService>.internal(
  userChatService,
  name: r'userChatServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userChatServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserChatServiceRef = ProviderRef<UserChatService>;
String _$chatInboxControllerHash() =>
    r'e4354e91e07e86f0de0c1b80282fb61ee14d640d';

/// See also [ChatInboxController].
@ProviderFor(ChatInboxController)
final chatInboxControllerProvider =
    NotifierProvider<ChatInboxController, ChatInboxState>.internal(
      ChatInboxController.new,
      name: r'chatInboxControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$chatInboxControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ChatInboxController = Notifier<ChatInboxState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
