import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'reservations_provider.g.dart';

/// Reservas próximas del usuario actual (esta semana)
@riverpod
Future<List<Map<String, dynamic>>> upcomingReservations(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final today = DateTime.now();
  final mondayOfWeek = today.subtract(Duration(days: (today.weekday - 1) % 7));
  final weekStart = DateTime(mondayOfWeek.year, mondayOfWeek.month, mondayOfWeek.day);
  final weekEnd = weekStart.add(const Duration(days: 7));

  String fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  final res = await supabase
      .from(AppConstants.tableReservations)
      .select('*, amenities(name)')
      .eq('user_id', user.id)
      .eq('status', AppConstants.statusConfirmed)
      .gte('reservation_date', fmtDate(weekStart))
      .lt('reservation_date', fmtDate(weekEnd))
      .order('reservation_date');

  return (res as List).map((e) {
    final map = Map<String, dynamic>.from(e as Map);
    map['amenity_name'] = (e['amenities'] as Map?)?['name'];
    return map;
  }).toList();
}

/// Slots ocupados para un día y amenity dados
@riverpod
Future<List<int>> occupiedSlots(
  Ref ref, {
  required String amenityId,
  required DateTime date,
}) async {
  final supabase = ref.watch(supabaseProvider);
  final dateStr =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  final res = await supabase
      .from(AppConstants.tableReservations)
      .select('start_hour')
      .eq('amenity_id', amenityId)
      .eq('reservation_date', dateStr)
      .eq('status', AppConstants.statusConfirmed);

  return (res as List).map((e) => (e as Map)['start_hour'] as int).toList();
}
