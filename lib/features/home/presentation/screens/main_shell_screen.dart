import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/screens/my_reservations_screen.dart';
import '../../../lottery/presentation/screens/lottery_screen.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  RealtimeChannel? _channel;

  static const _tabs = [
    _TabItem(icon: Icons.home_rounded, label: 'Inicio'),
    _TabItem(icon: Icons.casino_rounded, label: 'Sorteo'),
    _TabItem(icon: Icons.confirmation_number_rounded, label: 'Mis reservas'),
    _TabItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  static const _screens = [
    HomeScreen(),
    LotteryScreen(),
    MyReservationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupRealtime());
  }

  Future<void> _setupRealtime() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('user-notif-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: AppConstants.tableUserNotifications,
          // Sin filtro server-side — verificamos user_id en el cliente.
          // Más confiable que el filtro de columna que requiere REPLICA IDENTITY FULL.
          callback: (_) async {
            // El payload puede venir vacío sin REPLICA IDENTITY FULL.
            // Hacemos un query directo — RLS garantiza que solo vemos
            // las notificaciones del usuario autenticado.
            try {
              final rows = await Supabase.instance.client
                  .from(AppConstants.tableUserNotifications)
                  .select()
                  .eq('user_id', user.id)
                  .eq('read', false)
                  .order('created_at', ascending: false)
                  .limit(5);

              for (final notif in (rows as List)) {
                final title = notif['title'] as String? ?? '¡Buenas noticias!';
                final body  = notif['body']  as String? ?? '';
                await NotificationService.show(title: title, body: body);
                // Marcar como leída para no mostrarla de nuevo
                await Supabase.instance.client
                    .from(AppConstants.tableUserNotifications)
                    .update({'read': true})
                    .eq('id', notif['id'] as String);
              }
              ref.invalidate(unreadNotificationsProvider);
            } catch (_) {}
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(shellTabProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: tabIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hair)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final on = tabIndex == i;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ref.read(shellTabProvider.notifier).setTab(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tab.icon,
                            size: 24,
                            color: on
                                ? AppColors.accentDeep
                                : AppColors.textFaint),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight:
                                on ? FontWeight.w700 : FontWeight.w600,
                            color: on
                                ? AppColors.accentDeep
                                : AppColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
