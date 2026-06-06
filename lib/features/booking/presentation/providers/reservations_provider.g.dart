// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservations_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$upcomingReservationsHash() =>
    r'3c257db96d4e3f39a8a0f40e312746d3bd693374';

/// Reservas próximas del usuario — desde hoy hasta 14 días adelante.
/// Incluye las de la próxima semana asignadas por sorteo.
///
/// Copied from [upcomingReservations].
@ProviderFor(upcomingReservations)
final upcomingReservationsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      upcomingReservations,
      name: r'upcomingReservationsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$upcomingReservationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpcomingReservationsRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$weeklyReservationCountHash() =>
    r'ef835486ad15dd164fb82ffa0c7f66adf932c8b0';

/// Reservas solo de esta semana — para mostrar el cupo semanal (3/semana).
///
/// Copied from [weeklyReservationCount].
@ProviderFor(weeklyReservationCount)
final weeklyReservationCountProvider = AutoDisposeFutureProvider<int>.internal(
  weeklyReservationCount,
  name: r'weeklyReservationCountProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$weeklyReservationCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WeeklyReservationCountRef = AutoDisposeFutureProviderRef<int>;
String _$occupiedSlotsHash() => r'f79f90e68b39dedbe84bbf1b59e1da8a92b42277';

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

/// Slots ocupados para un día y amenity dados
///
/// Copied from [occupiedSlots].
@ProviderFor(occupiedSlots)
const occupiedSlotsProvider = OccupiedSlotsFamily();

/// Slots ocupados para un día y amenity dados
///
/// Copied from [occupiedSlots].
class OccupiedSlotsFamily extends Family<AsyncValue<List<int>>> {
  /// Slots ocupados para un día y amenity dados
  ///
  /// Copied from [occupiedSlots].
  const OccupiedSlotsFamily();

  /// Slots ocupados para un día y amenity dados
  ///
  /// Copied from [occupiedSlots].
  OccupiedSlotsProvider call({
    required String amenityId,
    required DateTime date,
  }) {
    return OccupiedSlotsProvider(amenityId: amenityId, date: date);
  }

  @override
  OccupiedSlotsProvider getProviderOverride(
    covariant OccupiedSlotsProvider provider,
  ) {
    return call(amenityId: provider.amenityId, date: provider.date);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'occupiedSlotsProvider';
}

/// Slots ocupados para un día y amenity dados
///
/// Copied from [occupiedSlots].
class OccupiedSlotsProvider extends AutoDisposeFutureProvider<List<int>> {
  /// Slots ocupados para un día y amenity dados
  ///
  /// Copied from [occupiedSlots].
  OccupiedSlotsProvider({required String amenityId, required DateTime date})
    : this._internal(
        (ref) => occupiedSlots(
          ref as OccupiedSlotsRef,
          amenityId: amenityId,
          date: date,
        ),
        from: occupiedSlotsProvider,
        name: r'occupiedSlotsProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$occupiedSlotsHash,
        dependencies: OccupiedSlotsFamily._dependencies,
        allTransitiveDependencies:
            OccupiedSlotsFamily._allTransitiveDependencies,
        amenityId: amenityId,
        date: date,
      );

  OccupiedSlotsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.amenityId,
    required this.date,
  }) : super.internal();

  final String amenityId;
  final DateTime date;

  @override
  Override overrideWith(
    FutureOr<List<int>> Function(OccupiedSlotsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: OccupiedSlotsProvider._internal(
        (ref) => create(ref as OccupiedSlotsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        amenityId: amenityId,
        date: date,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<int>> createElement() {
    return _OccupiedSlotsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is OccupiedSlotsProvider &&
        other.amenityId == amenityId &&
        other.date == date;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, amenityId.hashCode);
    hash = _SystemHash.combine(hash, date.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin OccupiedSlotsRef on AutoDisposeFutureProviderRef<List<int>> {
  /// The parameter `amenityId` of this provider.
  String get amenityId;

  /// The parameter `date` of this provider.
  DateTime get date;
}

class _OccupiedSlotsProviderElement
    extends AutoDisposeFutureProviderElement<List<int>>
    with OccupiedSlotsRef {
  _OccupiedSlotsProviderElement(super.provider);

  @override
  String get amenityId => (origin as OccupiedSlotsProvider).amenityId;
  @override
  DateTime get date => (origin as OccupiedSlotsProvider).date;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
