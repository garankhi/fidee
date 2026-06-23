// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$commentControllerHash() => r'b867bd2e27c21cc8c5acd9f1aac225d77e974bda';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$CommentController
    extends BuildlessAutoDisposeNotifier<CommentState> {
  late final String targetKey;

  CommentState build(String targetKey);
}

/// See also [CommentController].
@ProviderFor(CommentController)
const commentControllerProvider = CommentControllerFamily();

/// See also [CommentController].
class CommentControllerFamily extends Family<CommentState> {
  /// See also [CommentController].
  const CommentControllerFamily();

  /// See also [CommentController].
  CommentControllerProvider call(String targetKey) {
    return CommentControllerProvider(targetKey);
  }

  @override
  CommentControllerProvider getProviderOverride(
    covariant CommentControllerProvider provider,
  ) {
    return call(provider.targetKey);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'commentControllerProvider';
}

/// See also [CommentController].
class CommentControllerProvider
    extends AutoDisposeNotifierProviderImpl<CommentController, CommentState> {
  /// See also [CommentController].
  CommentControllerProvider(String targetKey)
    : this._internal(
        () => CommentController()..targetKey = targetKey,
        from: commentControllerProvider,
        name: r'commentControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$commentControllerHash,
        dependencies: CommentControllerFamily._dependencies,
        allTransitiveDependencies:
            CommentControllerFamily._allTransitiveDependencies,
        targetKey: targetKey,
      );

  CommentControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.targetKey,
  }) : super.internal();

  final String targetKey;

  @override
  CommentState runNotifierBuild(covariant CommentController notifier) {
    return notifier.build(targetKey);
  }

  @override
  Override overrideWith(CommentController Function() create) {
    return ProviderOverride(
      origin: this,
      override: CommentControllerProvider._internal(
        () => create()..targetKey = targetKey,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        targetKey: targetKey,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<CommentController, CommentState>
  createElement() {
    return _CommentControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is CommentControllerProvider && other.targetKey == targetKey;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, targetKey.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin CommentControllerRef on AutoDisposeNotifierProviderRef<CommentState> {
  /// The parameter `targetKey` of this provider.
  String get targetKey;
}

class _CommentControllerProviderElement
    extends AutoDisposeNotifierProviderElement<CommentController, CommentState>
    with CommentControllerRef {
  _CommentControllerProviderElement(super.provider);

  @override
  String get targetKey => (origin as CommentControllerProvider).targetKey;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
