import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'lottery_provider.g.dart';

// ── Helpers ──────────────────────────────────────────────────────────────

String lotteryFmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _thisMonday() {
  final t = DateTime.now();
  return DateTime(t.year, t.month, t.day - (t.weekday - 1));
}

// ── Phase ────────────────────────────────────────────────────────────────

enum LotteryPhase {
  open,     // Sáb–Dom: elegir horarios para la próxima semana
  drawDay,  // Viernes: se realiza el sorteo
  results,  // Lun–Jue: ver resultados de esta semana
}

@riverpod
LotteryPhase lotteryPhase(Ref ref) {
  final w = DateTime.now().weekday;
  if (w == DateTime.friday) return LotteryPhase.drawDay;
  if (w <= DateTime.thursday) return LotteryPhase.results;
  return LotteryPhase.open; // Sat=6, Sun=7
}

/// Lunes de la semana a la que corresponde el sorteo activo
@riverpod
DateTime lotteryWeekStart(Ref ref) {
  final w = DateTime.now().weekday;
  final thisMonday = _thisMonday();
  // Lun–Jue → semana actual (resultados); Vie–Dom → próxima semana (inscripción/sorteo)
  return w <= DateTime.thursday
      ? thisMonday
      : thisMonday.add(const Duration(days: 7));
}

// ── Data providers ────────────────────────────────────────────────────────

@riverpod
Future<List<Map<String, dynamic>>> myLotteryEntries(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final supabase = ref.watch(supabaseProvider);
  final weekStart = ref.watch(lotteryWeekStartProvider);

  final res = await supabase
      .from(AppConstants.tableLotteryEntries)
      .select()
      .eq('user_id', user.id)
      .eq('week_start', lotteryFmtDate(weekStart))
      .order('priority');

  return List<Map<String, dynamic>>.from(res as List);
}

@riverpod
Future<bool> lotteryDrawDone(Ref ref) async {
  final supabase = ref.watch(supabaseProvider);
  final weekStart = ref.watch(lotteryWeekStartProvider);

  final res = await supabase
      .from(AppConstants.tableLotteryDraws)
      .select('id')
      .eq('week_start', lotteryFmtDate(weekStart))
      .maybeSingle();

  return res != null;
}
