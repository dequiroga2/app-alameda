// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$connectivityStreamHash() =>
    r'dbd2c4ce5970f1f97dad2730821bb5ca0b99c327';

/// See also [connectivityStream].
@ProviderFor(connectivityStream)
final connectivityStreamProvider =
    AutoDisposeStreamProvider<List<ConnectivityResult>>.internal(
      connectivityStream,
      name: r'connectivityStreamProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$connectivityStreamHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ConnectivityStreamRef =
    AutoDisposeStreamProviderRef<List<ConnectivityResult>>;
String _$hasConnectionHash() => r'58c416be7ca33b5d3e593be8086bb10e5d7522ed';

/// See also [hasConnection].
@ProviderFor(hasConnection)
final hasConnectionProvider = AutoDisposeFutureProvider<bool>.internal(
  hasConnection,
  name: r'hasConnectionProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$hasConnectionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HasConnectionRef = AutoDisposeFutureProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
