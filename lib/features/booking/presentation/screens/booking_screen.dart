import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/reservations_provider.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, required this.amenityId});
  final String amenityId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  late DateTime _selectedDate;
  int? _selectedHour;
  bool _confirming = false;

  final _amenityName = 'Cancha de tenis'; // en producción: cargado desde Supabase

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  List<DateTime> get _bookableDays {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // Sáb–Dom: hasta el domingo de la PRÓXIMA semana (sorteos ya publicados)
    // Lun–Vie: solo hasta el domingo de ESTA semana
    final daysUntilEnd = today.weekday >= DateTime.saturday
        ? DateTime.sunday - today.weekday + 7  // sáb=8 días, dom=7 días
        : DateTime.sunday - today.weekday;     // lun=6, mar=5 … vie=2
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

      // Leemos tower y apartment del perfil del usuario
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
      });

      // Fuerza recarga de reservas en home
      ref.invalidate(upcomingReservationsProvider);

      if (mounted) {
        context.pushReplacement('/confirm', extra: {
          'reservationId': id,
          'amenityName': _amenityName,
          'date': _selectedDate,
          'hour': _selectedHour!,
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
    final occupiedAsync = ref.watch(
      occupiedSlotsProvider(amenityId: widget.amenityId, date: _selectedDate),
    );
    final occupied = occupiedAsync.valueOrNull ?? [];
    final weeklyUsed = ref.watch(weeklyReservationCountProvider).valueOrNull ?? 0;
    final weeklyFull = weeklyUsed >= AppConstants.weeklyReservationLimit;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Encabezado con días
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
                // Chips de días — scroll horizontal
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
                        }),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),

          // Grilla de horas
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
                      Text('Toca una hora',
                          style: AppTextStyles.caption.copyWith(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.4,
                    ),
                    itemCount: _hours.length,
                    itemBuilder: (context, i) {
                      final h = _hours[i];
                      final isOccupied = occupied.contains(h) || _isPseudoOccupied(i, h);
                      final isSelected = _selectedHour == h;
                      return _HourTile(
                        hour: h,
                        isOccupied: isOccupied,
                        isSelected: isSelected,
                        onTap: isOccupied ? null : () => setState(() => _selectedHour = h),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // Barra inferior fija de confirmación
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
                  const Icon(Icons.block_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Alcanzaste el límite de 3 reservas esta semana. Disponibles el lunes.',
                      style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
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
                            style: AppTextStyles.caption.copyWith(fontSize: 12)),
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
                    label: 'Confirmar',
                    onPressed: _selectedHour != null ? _confirm : null,
                    size: AppButtonSize.lg,
                    icon: Icons.check_rounded,
                    loading: _confirming,
                  ),
                ],
              ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _mapBookingError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('3 reservas por semana') || msg.contains('weekly')) {
      return 'Tu unidad ya usó las 3 reservas de esta semana. Disponibles el lunes.';
    }
    if (msg.contains('una reserva para esta unidad este día') || msg.contains('daily')) {
      return 'Tu unidad ya tiene una reserva para este día.';
    }
    if (msg.contains('unique_slot') || msg.contains('unique constraint') || msg.contains('already exists')) {
      return 'Ese horario acaba de ser tomado por otro residente. Elige otra hora.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Sin conexión. Verifica tu internet e intenta de nuevo.';
    }
    return 'No se pudo confirmar la reserva. Intenta de nuevo.';
  }

  // Ocupación pseudo-aleatoria determinista para la demo
  // En producción esto viene de Supabase en tiempo real
  bool _isPseudoOccupied(int dayOffset, int hour) {
    final s = (dayOffset * 31 + hour * 17 + 7) % 100;
    final peak = (hour <= 8 || (hour >= 17 && hour <= 19)) ? 55 : 28;
    return s < peak;
  }

  String _dayLabel(DateTime d) {
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
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

// ── Widgets locales ────────────────────────────────────────────────────

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
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final topLabel = index == 0 ? 'Hoy' : index == 1 ? 'Mañ.' : days[date.weekday % 7];

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
                color: isSelected ? Colors.white.withValues(alpha: 0.85) : AppColors.textFaint,
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
                color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textFaint,
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
    required this.isOccupied,
    required this.isSelected,
    this.onTap,
  });

  final int hour;
  final bool isOccupied;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '$h12:00 $ampm';
    }

    final bg = isSelected
        ? AppColors.accentStrong
        : isOccupied
            ? AppColors.background
            : AppColors.surface;
    final fgStrong = isSelected
        ? Colors.white
        : isOccupied
            ? AppColors.textFaint
            : AppColors.textPrimary;
    final fgSoft = isSelected
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.textFaint;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accentStrong : AppColors.hair,
            width: 1.5,
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
              isOccupied ? 'Ocupado' : 'hasta ${fmt(hour + 1).replaceAll(' a.m.', '').replaceAll(' p.m.', '')}',
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
