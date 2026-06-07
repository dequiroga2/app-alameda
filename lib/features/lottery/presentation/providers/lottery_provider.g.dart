// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lottery_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$lotteryPhaseHash() => r'5ad447932de5222b82568216cda3e05969bd99f5';

/// See also [lotteryPhase].
@ProviderFor(lotteryPhase)
final lotteryPhaseProvider = AutoDisposeProvider<LotteryPhase>.internal(
  lotteryPhase,
  name: r'lotteryPhaseProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$lotteryPhaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LotteryPhaseRef = AutoDisposeProviderRef<LotteryPhase>;
String _$lotteryWeekStartHash() => r'89cd6d20d881280dd0c05b087cdbdf7ef6e0b17b';

/// Lunes de la semana a la que corresponde el sorteo activo
///
/// Copied from [lotteryWeekStart].
@ProviderFor(lotteryWeekStart)
final lotteryWeekStartProvider = AutoDisposeProvider<DateTime>.internal(
  lotteryWeekStart,
  name: r'lotteryWeekStartProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lotteryWeekStartHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LotteryWeekStartRef = AutoDisposeProviderRef<DateTime>;
String _$myLotteryEntriesHash() => r'f7a5200ec5e1e0ed243880d9e534395fd57f78b8';

/// See also [myLotteryEntries].
@ProviderFor(myLotteryEntries)
final myLotteryEntriesProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      myLotteryEntries,
      name: r'myLotteryEntriesProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$myLotteryEntriesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyLotteryEntriesRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$lotteryDrawDoneHash() => r'82bef3e7144fa7d3aae84db97655fded2626badb';

/// See also [lotteryDrawDone].
@ProviderFor(lotteryDrawDone)
final lotteryDrawDoneProvider = AutoDisposeFutureProvider<bool>.internal(
  lotteryDrawDone,
  name: r'lotteryDrawDoneProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$lotteryDrawDoneHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LotteryDrawDoneRef = AutoDisposeFutureProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
