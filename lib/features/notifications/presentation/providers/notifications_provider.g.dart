// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadNotificationsHash() =>
    r'ebfa1c4003a44d1ad8fbc69c9ac04831ecac51b4';

/// Notificaciones no leídas del usuario actual (máx. 10).
/// Se usa para mostrar banners en la pantalla de inicio cuando,
/// por ejemplo, el primer inscrito canceló y la reserva pasó al usuario.
///
/// Copied from [unreadNotifications].
@ProviderFor(unreadNotifications)
final unreadNotificationsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
      unreadNotifications,
      name: r'unreadNotificationsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$unreadNotificationsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNotificationsRef =
    AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
