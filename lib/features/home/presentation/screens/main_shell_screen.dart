import 'dart:async';
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
  StreamSubscription<AuthState>? _authSub;
  OverlayEntry? _bannerEntry;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupRealtime();
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.tokenRefreshed) {
          _channel?.unsubscribe();
          _channel = null;
          _setupRealtime();
        }
      });
    });
  }

  Future<void> _setupRealtime() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    _channel = Supabase.instance.client
        .channel('user-notif-${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: AppConstants.tableUserNotifications,
          callback: (_) async {
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

                // Banner in-app (funciona en todos los simuladores y dispositivos)
                if (mounted) _showInAppBanner(title, body);

                // Notificación nativa (para cuando la app está en background)
                await NotificationService.show(title: title, body: body);

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

  /// Banner que se desliza desde arriba — funciona en cualquier iOS/Android.
  void _showInAppBanner(String title, String body) {
    _bannerEntry?.remove();
    _bannerEntry = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _InAppBanner(
        title: title,
        body: body,
        onDismiss: () {
          entry.remove();
          if (_bannerEntry == entry) _bannerEntry = null;
        },
      ),
    );

    overlay.insert(entry);
    _bannerEntry = entry;

    // Auto-dismiss después de 4 segundos
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
        if (_bannerEntry == entry) _bannerEntry = null;
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _channel?.unsubscribe();
    _bannerEntry?.remove();
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

// ── In-App Notification Banner ────────────────────────────────────────────────

class _InAppBanner extends StatefulWidget {
  const _InAppBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
  });
  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  State<_InAppBanner> createState() => _InAppBannerState();
}

class _InAppBannerState extends State<_InAppBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Ícono de la app
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentStrong,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sports_tennis_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.body,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab item ──────────────────────────────────────────────────────────────────

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
