import 'dart:async';

import 'package:flutter/foundation.dart';
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

// ── Court status enum ─────────────────────────────────────────────────────────

enum _CourtStatus { available, occupied, closed }

// ── HomeScreen ────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Updated once a minute — used to detect hour changes for court status
  DateTime _now = DateTime.now();
  Timer? _minuteTimer;

  // Debug-only: override court status manually (null = automatic)
  _CourtStatus? _debugStatus;

  @override
  void initState() {
    super.initState();
    // Tick every 30 s so status reacts within half a minute of hour change
    _minuteTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final reservations = ref.watch(upcomingReservationsProvider);
    final top = MediaQuery.of(context).padding.top;

    final userName = user?.userMetadata?['full_name']?.toString().split(' ').first ?? 'Residente';
    final tower = user?.userMetadata?['tower']?.toString() ?? '';
    final apt = user?.userMetadata?['apartment']?.toString() ?? '';

    final dateStr = _formatDate(_now);

    // ── Court status ─────────────────────────────────────────────────────
    final todayDate = DateTime(_now.year, _now.month, _now.day);
    final occupiedToday = ref
        .watch(occupiedSlotsProvider(
          amenityId: AppConstants.lotteryAmenityId,
          date: todayDate,
        ))
        .valueOrNull ?? [];

    final courtStatus = _debugStatus ?? _computeStatus(_now, occupiedToday);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accentStrong,
        onRefresh: () async {
          ref.invalidate(upcomingReservationsProvider);
          ref.invalidate(weeklyReservationCountProvider);
          await ref.read(upcomingReservationsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: WaveHeader(
                backgroundColor: AppColors.background,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, top + 16, 24, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date + greeting
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.accentDeep.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Hola, $userName 👋', style: AppTextStyles.headlineLg),
                            if (tower.isNotEmpty && apt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Torre $tower · Apto $apt',
                                style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.textFaint),
                              ),
                            ],
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      // Live clock — top right, subtle
                      const _LiveClock(),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Amenity card ──────────────────────────────────────
                  _AmenityCard(
                    name: 'Cancha de tenis',
                    schedule: '7:00 a.m. – 9:00 p.m.',
                    status: courtStatus,
                    onBook: () => context.push('/booking/tenis'),
                    onStatusTap: kDebugMode ? _cycleDebugStatus : null,
                  ),
                  const SizedBox(height: 16),

                  // Debug status toggle (debug only)
                  if (kDebugMode) _DebugStatusPanel(
                    current: _debugStatus,
                    onSelect: (s) => setState(() => _debugStatus = s),
                  ),
                  if (kDebugMode) const SizedBox(height: 16),

                  // ── Weekly quota ──────────────────────────────────────
                  Builder(builder: (context) {
                    final now = DateTime.now();
                    final isWeekend = now.weekday >= DateTime.saturday;
                    final referenceDate = isWeekend
                        ? _todayDate().add(const Duration(days: 7))
                        : _todayDate();
                    return ref
                        .watch(weeklyReservationCountProvider(referenceDate))
                        .when(
                      data: (count) =>
                          _WeeklyQuota(used: count, nextWeek: isWeekend),
                      loading: () => const _QuotaShimmer(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  }),
                  const SizedBox(height: 16),

                  // ── Upcoming reservations ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Próximas reservas', style: AppTextStyles.titleLg),
                      if (reservations.valueOrNull?.isNotEmpty ?? false)
                        TextButton(
                          onPressed: () =>
                              ref.read(shellTabProvider.notifier).setTab(2),
                          child: Text(
                            (reservations.valueOrNull?.length ?? 0) > 3
                                ? 'Ver todas (${reservations.valueOrNull!.length})'
                                : 'Ver todas',
                            style: AppTextStyles.labelLg
                                .copyWith(color: AppColors.accentDeep),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  reservations.when(
                    data: (list) => list.isEmpty
                        ? _EmptyReservations(
                            onBook: () => context.push('/booking/tenis'))
                        : Column(
                            children: [
                              ...list.take(3).map((r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _ReservationTile(
                                      reservation: r,
                                      onCancel: () => _cancelReservation(
                                          context, ref, r),
                                    ),
                                  )),
                              if (list.length > 3)
                                GestureDetector(
                                  onTap: () => ref
                                      .read(shellTabProvider.notifier)
                                      .setTab(2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                            Icons.calendar_month_rounded,
                                            size: 16,
                                            color: AppColors.accentDeep),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Y ${list.length - 3} reserva${list.length - 3 == 1 ? '' : 's'} más',
                                          style: AppTextStyles.labelMd
                                              .copyWith(
                                                  color:
                                                      AppColors.accentDeep),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: AppColors.accentDeep),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                    loading: () => const _ReservationShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  _CourtStatus _computeStatus(DateTime now, List<int> occupied) {
    if (now.hour < 7 || now.hour >= 21) return _CourtStatus.closed;
    if (occupied.contains(now.hour)) return _CourtStatus.occupied;
    return _CourtStatus.available;
  }

  void _cycleDebugStatus() {
    setState(() {
      _debugStatus = switch (_debugStatus) {
        null => _CourtStatus.occupied,
        _CourtStatus.available => _CourtStatus.occupied,
        _CourtStatus.occupied => _CourtStatus.closed,
        _CourtStatus.closed => null, // back to auto
      };
    });
  }

  DateTime _todayDate() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _formatDate(DateTime d) {
    const days = [
      'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final day = days[d.weekday % 7];
    final month = months[d.month - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day} de $month';
  }

  Future<void> _cancelReservation(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final date = DateTime.parse(r['reservation_date'] as String);
    final hour = r['start_hour'] as int;
    const days = [
      'domingo', 'lunes', 'martes', 'miércoles',
      'jueves', 'viernes', 'sábado'
    ];
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

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
            Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: AppColors.hair,
                    borderRadius: BorderRadius.circular(99))),
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
      try {
        await Supabase.instance.client
            .from(AppConstants.tableReservations)
            .update({'status': AppConstants.statusCancelled})
            .eq('id', r['id'] as String);
        ref.invalidate(upcomingReservationsProvider);
        ref.invalidate(weeklyReservationCountProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo cancelar. Intenta de nuevo.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    }
  }
}

// ── Live Clock ────────────────────────────────────────────────────────────────

class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    final s = _now.second.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hair, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDeep.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.access_time_rounded,
              size: 12, color: AppColors.accentDeep),
          const SizedBox(width: 5),
          Text(
            '$h:$m:',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.accentDeep.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontFamilyFallback: const ['monospace'],
            ),
          ),
          Text(
            s,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.accentDeep.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontFamilyFallback: const ['monospace'],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Debug panel (debug builds only) ─────────────────────────────────────────

class _DebugStatusPanel extends StatelessWidget {
  const _DebugStatusPanel({required this.current, required this.onSelect});
  final _CourtStatus? current;
  final void Function(_CourtStatus?) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report_rounded,
                  size: 14, color: Colors.deepPurple),
              const SizedBox(width: 6),
              Text(
                'DEBUG · Estado de la cancha',
                style: AppTextStyles.labelSm.copyWith(
                  color: Colors.deepPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (current != null)
                GestureDetector(
                  onTap: () => onSelect(null),
                  child: Text(
                    'Auto',
                    style: AppTextStyles.labelSm.copyWith(
                      color: Colors.deepPurple,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _DebugChip(
                label: 'Disponible',
                selected: current == _CourtStatus.available,
                color: AppColors.accentDeep,
                onTap: () => onSelect(_CourtStatus.available),
              ),
              const SizedBox(width: 8),
              _DebugChip(
                label: 'Ocupada',
                selected: current == _CourtStatus.occupied,
                color: AppColors.warning,
                onTap: () => onSelect(_CourtStatus.occupied),
              ),
              const SizedBox(width: 8),
              _DebugChip(
                label: 'Cerrada',
                selected: current == _CourtStatus.closed,
                color: AppColors.textFaint,
                onTap: () => onSelect(_CourtStatus.closed),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugChip extends StatelessWidget {
  const _DebugChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.35),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: selected ? color : color.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _AmenityCard extends StatelessWidget {
  const _AmenityCard({
    required this.name,
    required this.schedule,
    required this.status,
    required this.onBook,
    this.onStatusTap,
  });
  final String name;
  final String schedule;
  final _CourtStatus status;
  final VoidCallback onBook;
  final VoidCallback? onStatusTap; // debug: long-press to cycle

  @override
  Widget build(BuildContext context) {
    // Status visuals
    final (label, dotColor, bgColor, textColor) = switch (status) {
      _CourtStatus.available => (
          'Disponible',
          AppColors.accentStrong,
          AppColors.accentTint,
          AppColors.accentDeep,
        ),
      _CourtStatus.occupied => (
          'Ocupada ahora',
          AppColors.warning,
          AppColors.warning.withValues(alpha: 0.12),
          AppColors.warning,
        ),
      _CourtStatus.closed => (
          'Cerrada',
          AppColors.textFaint,
          AppColors.hair,
          AppColors.textFaint,
        ),
    };

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image placeholder
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: status == _CourtStatus.closed
                    ? [AppColors.hair, AppColors.hair.withValues(alpha: 0.6)]
                    : [AppColors.accentTint, AppColors.accentSoft],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    status == _CourtStatus.closed
                        ? Icons.lock_outline_rounded
                        : Icons.sports_tennis_rounded,
                    color: status == _CourtStatus.closed
                        ? AppColors.textFaint
                        : AppColors.accentDeep,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'foto cancha de tenis',
                    style: AppTextStyles.caption.copyWith(
                        fontFamily: 'monospace', color: AppColors.accentDeep),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Text(name, style: AppTextStyles.headlineSm)),
              // Status badge — long-press to cycle in debug
              GestureDetector(
                onTap: onStatusTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: textColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                status == _CourtStatus.closed
                    ? Icons.lock_clock_rounded
                    : Icons.access_time_rounded,
                size: 15,
                color: AppColors.textFaint,
              ),
              const SizedBox(width: 6),
              Text('Horario $schedule', style: AppTextStyles.bodyMd),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: status == _CourtStatus.closed
                ? 'Reservar para después'
                : 'Reservar cancha',
            onPressed: onBook,
            size: AppButtonSize.lg,
            fullWidth: true,
            icon: status == _CourtStatus.closed
                ? Icons.calendar_today_rounded
                : Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}

class _WeeklyQuota extends StatelessWidget {
  const _WeeklyQuota({required this.used, this.nextWeek = false});
  final int used;
  final bool nextWeek;
  static const _limit = 3;

  @override
  Widget build(BuildContext context) {
    final remaining = _limit - used;
    final title = nextWeek ? 'Próxima semana' : 'Esta semana';
    final subtitle = nextWeek
        ? (remaining > 0
            ? 'Te ${remaining == 1 ? 'queda' : 'quedan'} $remaining '
                '${remaining == 1 ? 'reserva' : 'reservas'} para reservar o sortear.'
            : 'Semana llena — no hay más cupo disponible.')
        : (remaining > 0
            ? 'Te ${remaining == 1 ? 'queda' : 'quedan'} $remaining '
                '${remaining == 1 ? 'reserva disponible' : 'reservas disponibles'}.'
            : 'Alcanzaste el máximo. Desde el sábado puedes planear la próxima.');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Text('Tus reservas · ', style: AppTextStyles.titleMd),
                Text(
                  title,
                  style: AppTextStyles.titleMd.copyWith(
                      color: nextWeek
                          ? AppColors.accentDeep
                          : AppColors.textPrimary),
                ),
              ]),
              Text('$used de $_limit',
                  style: AppTextStyles.labelMd
                      .copyWith(color: AppColors.textFaint)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              _limit,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _limit - 1 ? 8 : 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < used
                          ? AppColors.accentStrong
                          : AppColors.hair,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: AppTextStyles.caption.copyWith(
                color: remaining == 0
                    ? AppColors.warning
                    : AppColors.textFaint),
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
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_today_rounded,
                color: AppColors.accentStrong, size: 24),
          ),
          const SizedBox(height: 12),
          Text('Aún no tienes reservas',
              style: AppTextStyles.titleMd, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile(
      {required this.reservation, required this.onCancel});
  final Map<String, dynamic> reservation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final date =
        DateTime.parse(reservation['reservation_date'] as String);
    final hour = reservation['start_hour'] as int;
    final amenityName =
        reservation['amenity_name'] as String? ?? 'Zona común';

    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    final dayLabel = days[date.weekday % 7];

    return GestureDetector(
      onTap: onCancel,
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabel.toUpperCase(),
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.accentDeep, fontSize: 10),
                  ),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.headlineSm
                        .copyWith(color: AppColors.accentDeep),
                  ),
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
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textFaint),
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
