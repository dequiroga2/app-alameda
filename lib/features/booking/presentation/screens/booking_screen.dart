import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/reservations_provider.dart';

// Estado visual de cada tile de hora
enum _SlotState { free, secondAvailable, fullyOccupied, past }

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.amenityId});
  final String amenityId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late DateTime _selectedDate;
  int? _selectedHour;
  bool _selectedIsSecond = false; // ¿La hora seleccionada es 2da opción?
  bool _confirming = false;
  RealtimeChannel? _channel;

  final _amenityName = 'Cancha de tenis';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _subscribeToSlots();
  }

  /// Suscripción Realtime: cuando alguien reserva o cancela,
  /// el provider se recarga y la grilla se actualiza al instante.
  void _subscribeToSlots() {
    _channel = Supabase.instance.client
        .channel('booking-slots-${widget.amenityId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,   // INSERT, UPDATE, DELETE
          schema: 'public',
          table: AppConstants.tableReservations,
          callback: (_) {
            // Invalida el provider para la fecha actualmente visible
            if (mounted) {
              ref.invalidate(
                occupiedSlotsProvider(
                  amenityId: widget.amenityId,
                  date: _selectedDate,
                ),
              );
              // Si la hora seleccionada ya no está disponible, deselecciona
              _clearSelectionIfUnavailable();
            }
          },
        )
        .subscribe();
  }

  /// Revisa si el slot seleccionado se llenó tras una actualización en tiempo real.
  void _clearSelectionIfUnavailable() {
    if (_selectedHour == null) return;
    final slotMap = ref
        .read(occupiedSlotsProvider(amenityId: widget.amenityId, date: _selectedDate))
        .valueOrNull ?? {};
    final taken = slotMap[_selectedHour] ?? 0;
    // Si era 1ra opción y ya hay 2 opciones tomadas, o era 2da y ya está lleno
    final nowFull = taken >= 2;
    final wasFirst = !_selectedIsSecond && taken >= 1;
    if (nowFull || wasFirst) {
      setState(() {
        _selectedHour = null;
        _selectedIsSecond = false;
      });
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  List<DateTime> get _bookableDays {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final daysUntilEnd = today.weekday >= DateTime.saturday
        ? DateTime.sunday - today.weekday + 7
        : DateTime.sunday - today.weekday;
    return List.generate(
      daysUntilEnd + 1,
      (i) => todayDate.add(Duration(days: i)),
    );
  }

  List<int> get _hours => List.generate(
        AppConstants.lastBookingHour - AppConstants.firstBookingHour + 1,
        (i) => AppConstants.firstBookingHour + i,
      );

  Future<void> _confirm() async {
    if (_selectedHour == null) return;
    setState(() => _confirming = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes iniciar sesión para reservar.')),
          );
          setState(() => _confirming = false);
        }
        return;
      }

      final supabase = ref.read(supabaseProvider);
      final id = const Uuid().v4();
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      final profile = await supabase
          .from(AppConstants.tableProfiles)
          .select('tower, apartment')
          .eq('id', user.id)
          .single();

      await supabase.from(AppConstants.tableReservations).insert({
        'id': id,
        'user_id': user.id,
        'tower': profile['tower'],
        'apartment': profile['apartment'],
        'amenity_id': widget.amenityId,
        'reservation_date': dateStr,
        'start_hour': _selectedHour,
        'end_hour': _selectedHour! + 1,
        'status': AppConstants.statusConfirmed,
        'slot_option': _selectedIsSecond ? 2 : 1,
      });

      ref.invalidate(upcomingReservationsProvider);
      ref.invalidate(weeklyReservationCountProvider);

      if (mounted) {
        context.pushReplacement('/confirm', extra: {
          'reservationId': id,
          'amenityName': _amenityName,
          'date': _selectedDate,
          'hour': _selectedHour!,
          'isSecondOption': _selectedIsSecond,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_mapBookingError(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final slotsAsync = ref.watch(
      occupiedSlotsProvider(amenityId: widget.amenityId, date: _selectedDate),
    );
    final slotMap = slotsAsync.valueOrNull ?? {};

    final now = DateTime.now();
    final isToday = _isSameDay(_selectedDate, now);
    final pastHours = isToday
        ? List.generate(now.hour + 1, (i) => AppConstants.firstBookingHour + i)
            .where((h) => h <= now.hour)
            .toList()
        : <int>[];

    final weeklyUsed = ref.watch(
      weeklyReservationCountProvider(_selectedDate),
    ).valueOrNull ?? 0;
    final weeklyFull = weeklyUsed >= AppConstants.weeklyReservationLimit;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header con días ──────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.hair, width: 1.5),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 16, color: AppColors.textPrimary),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reservar cancha', style: AppTextStyles.headlineSm),
                          Text('Tenis · bloques de 1 hora',
                              style: AppTextStyles.bodyMd),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: _bookableDays.length,
                    itemBuilder: (context, i) {
                      final day = _bookableDays[i];
                      final isSelected = _isSameDay(day, _selectedDate);
                      return _DayChip(
                        date: day,
                        index: i,
                        isSelected: isSelected,
                        onTap: () => setState(() {
                          _selectedDate = day;
                          _selectedHour = null;
                          _selectedIsSecond = false;
                        }),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),

          // ── Grilla de horas ──────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dayLabel(_selectedDate),
                          style: AppTextStyles.titleLg),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: weeklyFull
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.accentTint,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$weeklyUsed/${AppConstants.weeklyReservationLimit} sem.',
                          style: AppTextStyles.labelSm.copyWith(
                            color: weeklyFull
                                ? AppColors.error
                                : AppColors.accentDeep,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Leyenda de colores
                  _SlotLegend(),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.4,
                    ),
                    itemCount: _hours.length,
                    itemBuilder: (context, i) {
                      final h = _hours[i];
                      final isPast = pastHours.contains(h);
                      final optionsTaken = slotMap[h] ?? 0;

                      final slotState = isPast
                          ? _SlotState.past
                          : optionsTaken >= 2
                              ? _SlotState.fullyOccupied
                              : optionsTaken == 1
                                  ? _SlotState.secondAvailable
                                  : _SlotState.free;

                      final canTap = !weeklyFull &&
                          slotState != _SlotState.past &&
                          slotState != _SlotState.fullyOccupied;

                      return _HourTile(
                        hour: h,
                        slotState: slotState,
                        isSelected: _selectedHour == h,
                        onTap: canTap
                            ? () => setState(() {
                                  _selectedHour = h;
                                  _selectedIsSecond =
                                      slotState == _SlotState.secondAvailable;
                                })
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Barra inferior ───────────────────────────────────────────────
      bottomSheet: Container(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.hair)),
        ),
        child: weeklyFull
            ? Row(
                children: [
                  const Icon(Icons.block_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _weekFullMessage(_selectedDate),
                      style:
                          AppTextStyles.labelSm.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Tu selección',
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 12)),
                        if (_selectedHour != null && _selectedIsSecond)
                          _SecondOptionLabel(
                            label:
                                '${_dayLabelShort(_selectedDate)} · ${_fmtRange(_selectedHour!)}',
                          )
                        else
                          Text(
                            _selectedHour != null
                                ? '${_dayLabelShort(_selectedDate)} · ${_fmtRange(_selectedHour!)}'
                                : 'Elige día y hora',
                            style: AppTextStyles.titleMd.copyWith(
                                color: _selectedHour != null
                                    ? AppColors.textPrimary
                                    : AppColors.textFaint),
                          ),
                      ],
                    ),
                  ),
                  AppButton(
                    label: _selectedIsSecond ? '2da opción' : 'Confirmar',
                    onPressed: _selectedHour != null ? _confirm : null,
                    size: AppButtonSize.lg,
                    icon: _selectedIsSecond
                        ? Icons.bookmark_add_rounded
                        : Icons.check_rounded,
                    loading: _confirming,
                  ),
                ],
              ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _weekStart(DateTime date) {
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  String _weekFullMessage(DateTime selectedDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedMonday = _weekStart(selectedDate);
    final currentMonday = _weekStart(today);

    if (selectedMonday == currentMonday) {
      return 'Alcanzaste el límite de 3 reservas esta semana. El lunes abre la próxima.';
    } else {
      const months = [
        'ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'
      ];
      final nextSun = selectedMonday.add(const Duration(days: 6));
      return 'Ya tienes 3 reservas la semana del ${selectedMonday.day} al ${nextSun.day} de ${months[nextSun.month - 1]}.';
    }
  }

  String _mapBookingError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('3 reservas por semana') || msg.contains('weekly')) {
      return 'Tu unidad ya usó las 3 reservas de esta semana.';
    }
    if (msg.contains('una reserva para esta unidad este día') ||
        msg.contains('daily')) {
      return 'Tu unidad ya tiene una reserva para este día.';
    }
    if (msg.contains('unique_slot') ||
        msg.contains('unique constraint') ||
        msg.contains('already exists')) {
      return 'Ese horario acaba de ser tomado. Elige otra hora.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'Sin conexión. Verifica tu internet e intenta de nuevo.';
    }
    return 'No se pudo confirmar la reserva. Intenta de nuevo.';
  }

  String _dayLabel(DateTime d) {
    const days = [
      'domingo', 'lunes', 'martes', 'miércoles',
      'jueves', 'viernes', 'sábado'
    ];
    final today = DateTime.now();
    if (_isSameDay(d, today)) return 'Hoy';
    if (_isSameDay(d, today.add(const Duration(days: 1)))) return 'Mañana';
    final day = days[d.weekday % 7];
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day}';
  }

  String _dayLabelShort(DateTime d) {
    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    return '${days[d.weekday % 7]} ${d.day}';
  }

  String _fmtRange(int h) {
    String fmt(int hh) {
      final ampm = hh < 12 ? 'a.m.' : 'p.m.';
      final h12 = hh % 12 == 0 ? 12 : hh % 12;
      return '$h12:00 $ampm';
    }
    return '${fmt(h)} – ${fmt(h + 1)}';
  }
}

// ── Leyenda ───────────────────────────────────────────────────────────────────

class _SlotLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(color: AppColors.accentStrong, label: 'Disponible'),
        const SizedBox(width: 14),
        _LegendDot(color: AppColors.warning, label: '2ª opción libre'),
        const SizedBox(width: 14),
        _LegendDot(color: AppColors.textFaint, label: 'Ocupado'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textFaint, fontSize: 11)),
      ],
    );
  }
}

// ── Label 2da opción en bottom bar ────────────────────────────────────────────

class _SecondOptionLabel extends StatelessWidget {
  const _SecondOptionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '2ª opción',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.titleMd),
      ],
    );
  }
}

// ── Widgets locales ───────────────────────────────────────────────────────────

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final topLabel =
        index == 0 ? 'Hoy' : index == 1 ? 'Mañ.' : days[date.weekday % 7];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 58,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentStrong : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accentStrong : AppColors.hair,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              topLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.textFaint,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            Text(
              months[date.month - 1].toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourTile extends StatelessWidget {
  const _HourTile({
    required this.hour,
    required this.slotState,
    required this.isSelected,
    this.onTap,
  });

  final int hour;
  final _SlotState slotState;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $ampm';
    }

    final Color bg;
    final Color fgStrong;
    final Color fgSoft;
    final String subLabel;
    final Color borderColor;

    if (isSelected) {
      // Seleccionado como 2da opción
      final isSecond = slotState == _SlotState.secondAvailable;
      bg = isSecond ? AppColors.warning : AppColors.accentStrong;
      fgStrong = Colors.white;
      fgSoft = Colors.white.withValues(alpha: 0.85);
      subLabel = isSecond ? '2da opción ✓' : 'Seleccionado';
      borderColor = bg;
    } else {
      switch (slotState) {
        case _SlotState.free:
          bg = AppColors.surface;
          fgStrong = AppColors.textPrimary;
          fgSoft = AppColors.textFaint;
          subLabel = 'hasta ${fmt(hour + 1).replaceAll(' a.m.', '').replaceAll(' p.m.', '')}';
          borderColor = AppColors.hair;
        case _SlotState.secondAvailable:
          bg = AppColors.warning.withValues(alpha: 0.08);
          fgStrong = AppColors.warning;
          fgSoft = AppColors.warning.withValues(alpha: 0.75);
          subLabel = '2ª opción libre';
          borderColor = AppColors.warning.withValues(alpha: 0.35);
        case _SlotState.fullyOccupied:
          bg = AppColors.background;
          fgStrong = AppColors.textFaint;
          fgSoft = AppColors.textFaint;
          subLabel = 'Ocupado';
          borderColor = AppColors.hair;
        case _SlotState.past:
          bg = AppColors.background;
          fgStrong = AppColors.textFaint;
          fgSoft = AppColors.textFaint;
          subLabel = 'Pasado';
          borderColor = AppColors.hair;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              fmt(hour),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: fgStrong,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fgSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
