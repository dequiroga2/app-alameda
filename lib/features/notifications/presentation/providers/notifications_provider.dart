import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

part 'notifications_provider.g.dart';

/// Notificaciones no leídas del usuario actual (máx. 10).
/// Se usa para mostrar banners en la pantalla de inicio cuando,
/// por ejemplo, el primer inscrito canceló y la reserva pasó al usuario.
@riverpod
Future<List<Map<String, dynamic>>> unreadNotifications(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final supabase = ref.watch(supabaseProvider);
  final res = await supabase
      .from(AppConstants.tableUserNotifications)
      .select()
      .eq('user_id', user.id)
      .eq('read', false)
      .order('created_at', ascending: false)
      .limit(10);

  return List<Map<String, dynamic>>.from(res as List);
}
