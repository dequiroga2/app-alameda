import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/shell_tab_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/wave_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/providers/reservations_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final reservations = ref.watch(upcomingReservationsProvider);
    final top = MediaQuery.of(context).padding.top;

    final userName = user?.userMetadata?['full_name']?.toString().split(' ').first ?? 'Residente';
    final tower = user?.userMetadata?['tower']?.toString() ?? '';
    final apt = user?.userMetadata?['apartment']?.toString() ?? '';

    final today = DateTime.now();
    final dateStr = _formatDate(today);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: WaveHeader(
              backgroundColor: AppColors.background,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, top + 16, 24, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.accentDeep.withValues(alpha: 0.8),
                    )),
                    const SizedBox(height: 4),
                    Text('Hola, $userName 👋', style: AppTextStyles.headlineLg),
                    if (tower.isNotEmpty && apt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Torre $tower · Apto $apt',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.textFaint),
                      ),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Card principal — cancha de tenis
                _AmenityCard(
                  name: 'Cancha de tenis',
                  schedule: '7:00 a.m. – 9:00 p.m.',
                  onBook: () => context.push('/booking/tenis'),
                ),
                const SizedBox(height: 16),

                // Cupo semanal
                ref.watch(weeklyReservationCountProvider).when(
                  data: (count) => _WeeklyQuota(used: count),
                  loading: () => const _QuotaShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),

                // Próximas reservas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Próximas reservas', style: AppTextStyles.titleLg),
                    if (reservations.valueOrNull?.isNotEmpty ?? false)
                      TextButton(
                        onPressed: () => ref.read(shellTabProvider.notifier).setTab(2),
                        child: Text('Ver todas',
                            style: AppTextStyles.labelLg.copyWith(color: AppColors.accentDeep)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                reservations.when(
                  data: (list) => list.isEmpty
                      ? _EmptyReservations(onBook: () => context.push('/booking/tenis'))
                      : Column(
                          children: list.take(3).map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ReservationTile(
                              reservation: r,
                              onCancel: () => _cancelReservation(context, ref, r),
                            ),
                          )).toList(),
                        ),
                  loading: () => const _ReservationShimmer(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelReservation(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final date = DateTime.parse(r['reservation_date'] as String);
    final hour = r['start_hour'] as int;
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
        'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $ampm';
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(
              color: AppColors.hair, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 20),
            Text('¿Cancelar reserva?', style: AppTextStyles.headlineSm),
            const SizedBox(height: 8),
            Text(
              '${days[date.weekday % 7][0].toUpperCase()}${days[date.weekday % 7].substring(1)} '
              '${date.day} de ${months[date.month - 1]} · ${fmt(hour)} – ${fmt(hour + 1)}',
              style: AppTextStyles.bodyLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Sí, cancelar',
              onPressed: () => Navigator.pop(context, true),
              variant: AppButtonVariant.danger,
              fullWidth: true,
              size: AppButtonSize.lg,
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Mantener reserva',
              onPressed: () => Navigator.pop(context, false),
              variant: AppButtonVariant.secondary,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from(AppConstants.tableReservations)
          .update({'status': AppConstants.statusCancelled})
          .eq('id', r['id'] as String);
      ref.invalidate(upcomingReservationsProvider);
    }
  }

  String _formatDate(DateTime d) {
    // Formato: "Martes 2 de junio"
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
        'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final day = days[d.weekday % 7];
    final month = months[d.month - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day} de $month';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({required this.name, required this.schedule, required this.onBook});
  final String name;
  final String schedule;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Placeholder de imagen
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.accentTint, AppColors.accentSoft],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_tennis_rounded,
                      color: AppColors.accentDeep, size: 48),
                  const SizedBox(height: 8),
                  Text('foto cancha de tenis',
                      style: AppTextStyles.caption.copyWith(
                          fontFamily: 'monospace', color: AppColors.accentDeep)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(name, style: AppTextStyles.headlineSm),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.accentStrong,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Disponible',
                        style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.accentDeep, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 15, color: AppColors.textFaint),
              const SizedBox(width: 6),
              Text('Horario $schedule', style: AppTextStyles.bodyMd),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Reservar cancha',
            onPressed: onBook,
            size: AppButtonSize.lg,
            fullWidth: true,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

class _WeeklyQuota extends StatelessWidget {
  const _WeeklyQuota({required this.used});
  final int used;
  static const _limit = 3;

  @override
  Widget build(BuildContext context) {
    final remaining = _limit - used;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tus reservas esta semana', style: AppTextStyles.titleMd),
              Text('$used de $_limit',
                  style: AppTextStyles.labelMd.copyWith(color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(height: 12),
          // Pips visuales
          Row(
            children: List.generate(_limit, (i) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < _limit - 1 ? 8 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < used ? AppColors.accentStrong : AppColors.hair,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            )),
          ),
          const SizedBox(height: 12),
          Text(
            remaining > 0
                ? 'Te ${remaining == 1 ? 'queda' : 'quedan'} $remaining ${remaining == 1 ? 'reserva disponible' : 'reservas disponibles'}.'
                : 'Alcanzaste el máximo semanal.',
            style: AppTextStyles.caption.copyWith(
                color: remaining == 0 ? AppColors.warning : AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}

class _EmptyReservations extends StatelessWidget {
  const _EmptyReservations({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: AppColors.accentStrong, size: 24),
          ),
          const SizedBox(height: 12),
          Text('Aún no tienes reservas', style: AppTextStyles.titleMd, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation, required this.onCancel});
  final Map<String, dynamic> reservation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(reservation['reservation_date'] as String);
    final hour = reservation['start_hour'] as int;
    final amenityName = reservation['amenity_name'] as String? ?? 'Zona común';

    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    final dayLabel = days[date.weekday % 7];

    return GestureDetector(
      onTap: onCancel,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52, height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(dayLabel.toUpperCase(), style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.accentDeep, fontSize: 10)),
                  Text('${date.day}', style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.accentDeep)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(amenityName, style: AppTextStyles.titleMd),
                  const SizedBox(height: 2),
                  Text(_formatRange(hour), style: AppTextStyles.bodyMd),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  String _formatRange(int h) {
    String fmt(int hh) {
      final ampm = hh < 12 ? 'a.m.' : 'p.m.';
      final h12 = hh % 12 == 0 ? 12 : hh % 12;
      return '$h12:00 $ampm';
    }
    return '${fmt(h)} – ${fmt(h + 1)}';
  }
}

class _QuotaShimmer extends StatelessWidget {
  const _QuotaShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.hair,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _ReservationShimmer extends StatelessWidget {
  const _ReservationShimmer();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.hair,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
