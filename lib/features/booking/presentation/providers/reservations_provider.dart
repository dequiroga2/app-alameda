import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'reservations_provider.g.dart';

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _weekStart(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return DateTime(monday.year, monday.month, monday.day);
}

/// Reservas próximas del usuario — desde hoy hasta 14 días adelante.
/// Incluye las de la próxima semana asignadas por sorteo.
@riverpod
Future<List<Map<String, dynamic>>> upcomingReservations(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final endDate = todayDate.add(const Duration(days: 14));

  final res = await supabase
      .from(AppConstants.tableReservations)
      .select('*, amenities(name)')
      .eq('user_id', user.id)
      .eq('status', AppConstants.statusConfirmed)
      .gte('reservation_date', _fmt(todayDate))
      .lt('reservation_date', _fmt(endDate))
      .order('reservation_date');

  return (res as List).map((e) {
    final map = Map<String, dynamic>.from(e as Map);
    map['amenity_name'] = (e['amenities'] as Map?)?['name'];
    return map;
  }).toList();
}

/// Cuántas reservas confirmadas tiene el usuario en la semana que contiene [date].
/// Pasa DateTime.now() para la semana actual, o la fecha seleccionada en booking.
@riverpod
Future<int> weeklyReservationCount(Ref ref, DateTime date) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final supabase = ref.watch(supabaseProvider);
  final start = _weekStart(date);
  final end   = start.add(const Duration(days: 7));

  final res = await supabase
      .from(AppConstants.tableReservations)
      .select('id')
      .eq('user_id', user.id)
      .eq('status', AppConstants.statusConfirmed)
      .gte('reservation_date', _fmt(start))
      .lt('reservation_date', _fmt(end));

  return (res as List).length;
}

/// Slots ocupados para un día y amenity dados
@riverpod
Future<List<int>> occupiedSlots(
  Ref ref, {
  required String amenityId,
  required DateTime date,
}) async {
  final supabase = ref.watch(supabaseProvider);

  final res = await supabase
      .from(AppConstants.tableReservations)
      .select('start_hour')
      .eq('amenity_id', amenityId)
      .eq('reservation_date', _fmt(date))
      .eq('status', AppConstants.statusConfirmed);

  return (res as List).map((e) => (e as Map)['start_hour'] as int).toList();
}
