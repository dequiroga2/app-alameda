import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/wave_header.dart';
import '../providers/reservations_provider.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservations = ref.watch(upcomingReservationsProvider);
    final top = MediaQuery.of(context).padding.top;

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
                    Text('Mis reservas', style: AppTextStyles.headlineLg),
                    reservations.when(
                      data: (list) => Text(
                        '${list.where((r) {
                          final d = DateTime.parse(r['reservation_date'] as String);
                          final now = DateTime.now();
                          final mon = now.subtract(Duration(days: now.weekday - 1));
                          final weekStart = DateTime(mon.year, mon.month, mon.day);
                          return !d.isBefore(weekStart) && d.isBefore(weekStart.add(const Duration(days: 7)));
                        }).length} de ${AppConstants.weeklyReservationLimit} usadas esta semana',
                        style: AppTextStyles.bodyMd.copyWith(color: AppColors.accentDeep.withValues(alpha: 0.8)),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            sliver: reservations.when(
              data: (list) => list.isEmpty
                  ? SliverToBoxAdapter(child: _EmptyState(onBook: () => context.push('/booking/tenis')))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          if (i == list.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: _AddMoreButton(onTap: () => context.push('/booking/tenis')),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ReservationCard(
                              reservation: list[i],
                              onCancel: () => _cancel(context, ref, list[i]),
                            ),
                          );
                        },
                        childCount: list.length + 1,
                      ),
                    ),
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext ctx, WidgetRef ref, Map<String, dynamic> r) async {
    final confirm = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => _CancelSheet(reservation: r),
    );
    if (confirm == true) {
      await Supabase.instance.client
          .from(AppConstants.tableReservations)
          .update({'status': AppConstants.statusCancelled})
          .eq('id', r['id'] as String);
      ref.invalidate(upcomingReservationsProvider);
    }
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onCancel});
  final Map<String, dynamic> reservation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(reservation['reservation_date'] as String);
    final hour = reservation['start_hour'] as int;
    final amenityName = reservation['amenity_name'] as String? ?? 'Zona común';

    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $ampm';
    }

    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
    final isTomorrow = date.difference(DateTime(today.year, today.month, today.day)).inDays == 1;
    final dateLabel = isToday ? 'Hoy' : isTomorrow ? 'Mañana' : '${days[date.weekday % 7]} ${date.day} ${months[date.month - 1]}';

    return AppCard(
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
                Text(days[date.weekday % 7].toUpperCase(),
                    style: AppTextStyles.labelSm.copyWith(color: AppColors.accentDeep, fontSize: 10)),
                Text('${date.day}', style: AppTextStyles.headlineSm.copyWith(color: AppColors.accentDeep)),
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
                Text('$dateLabel · ${fmt(hour)} – ${fmt(hour + 1)}',
                    style: AppTextStyles.bodyMd),
              ],
            ),
          ),
          AppButton(
            label: 'Cancelar',
            onPressed: onCancel,
            variant: AppButtonVariant.danger,
            size: AppButtonSize.sm,
          ),
        ],
      ),
    );
  }
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.reservation});
  final Map<String, dynamic> reservation;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(reservation['reservation_date'] as String);
    final hour = reservation['start_hour'] as int;
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
        'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $ampm';
    }

    return Padding(
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
            '${days[date.weekday % 7][0].toUpperCase()}${days[date.weekday % 7].substring(1)} ${date.day} de ${months[date.month - 1]} · ${fmt(hour)} – ${fmt(hour + 1)}',
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(34),
      child: Column(
        children: [
          Container(
            width: 56, height: 56,
            decoration: const BoxDecoration(color: AppColors.accentTint, shape: BoxShape.circle),
            child: const Icon(Icons.confirmation_number_rounded,
                color: AppColors.accentStrong, size: 28),
          ),
          const SizedBox(height: 14),
          Text('Sin reservas todavía', style: AppTextStyles.titleLg, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Reserva la cancha en unos segundos.',
              style: AppTextStyles.bodyMd, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          AppButton(label: 'Reservar cancha', onPressed: onBook, icon: Icons.add_rounded),
        ],
      ),
    );
  }
}

class _AddMoreButton extends StatelessWidget {
  const _AddMoreButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentSoft, width: 1.5,
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, color: AppColors.accentDeep, size: 20),
            const SizedBox(width: 8),
            Text('Nueva reserva',
                style: AppTextStyles.titleMd.copyWith(color: AppColors.accentDeep)),
          ],
        ),
      ),
    );
  }
}
