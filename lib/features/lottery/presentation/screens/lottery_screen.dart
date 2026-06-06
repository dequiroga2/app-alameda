import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/wave_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/lottery_provider.dart';

// ── Screen state machine ──────────────────────────────────────────────────
enum _Mode { loading, open, drawLoading, countdown, revealing, resultsStatic }

class LotteryScreen extends ConsumerStatefulWidget {
  const LotteryScreen({super.key});

  @override
  ConsumerState<LotteryScreen> createState() => _LotteryScreenState();
}

class _LotteryScreenState extends ConsumerState<LotteryScreen> {
  _Mode _mode = _Mode.loading;
  int _countdownValue = 3;
  int _revealedCount = 0;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final phase = ref.read(lotteryPhaseProvider);

    if (phase == LotteryPhase.open) {
      setState(() => _mode = _Mode.open);
      return;
    }

    // DRAW_DAY o RESULTS — check si ya vio la animación
    final weekStart = ref.read(lotteryWeekStartProvider);
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'lottery_reveal_seen_${lotteryFmtDate(weekStart)}';
    final alreadySeen = prefs.getBool(seenKey) ?? false;

    if (alreadySeen) {
      await _loadEntries();
      if (mounted) setState(() => _mode = _Mode.resultsStatic);
      return;
    }

    // Trigger del sorteo si es viernes y aún no se hizo
    if (phase == LotteryPhase.drawDay) {
      setState(() => _mode = _Mode.drawLoading);
      try {
        await Supabase.instance.client.rpc(
          'run_lottery_draw',
          params: {'p_week_start': lotteryFmtDate(weekStart)},
        );
      } catch (_) {
        // Idempotente: si ya se hizo, continúa
      }
    }

    await _loadEntries();

    if (_entries.isEmpty) {
      if (mounted) setState(() => _mode = _Mode.resultsStatic);
      await prefs.setBool(seenKey, true);
      return;
    }

    // Countdown 3 → 1
    if (!mounted) return;
    for (int c = 3; c >= 1; c--) {
      if (!mounted) return;
      setState(() { _mode = _Mode.countdown; _countdownValue = c; });
      await Future.delayed(const Duration(milliseconds: 900));
    }

    // Revelar carta por carta
    if (!mounted) return;
    setState(() { _mode = _Mode.revealing; _revealedCount = 0; });
    for (int i = 0; i < _entries.length; i++) {
      await Future.delayed(const Duration(milliseconds: 750));
      if (!mounted) return;
      setState(() => _revealedCount = i + 1);
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _mode = _Mode.resultsStatic);
    await prefs.setBool(seenKey, true);
  }

  Future<void> _loadEntries() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final weekStart = ref.read(lotteryWeekStartProvider);

    final res = await Supabase.instance.client
        .from(AppConstants.tableLotteryEntries)
        .select()
        .eq('user_id', user.id)
        .eq('week_start', lotteryFmtDate(weekStart))
        .order('slot_date')
        .order('start_hour');

    _entries = List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> _addEntry(String slotDate, int hour) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final weekStart = ref.read(lotteryWeekStartProvider);

    try {
      await Supabase.instance.client.from(AppConstants.tableLotteryEntries).insert({
        'user_id': user.id,
        'week_start': lotteryFmtDate(weekStart),
        'amenity_id': AppConstants.lotteryAmenityId,
        'slot_date': slotDate,
        'start_hour': hour,
      });
      ref.invalidate(myLotteryEntriesProvider);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg.contains('3 horarios')
              ? 'Solo puedes elegir 3 horarios por sorteo.'
              : msg.contains('unique') || msg.contains('duplicate')
                  ? 'Ya tienes ese horario en tu lista.'
                  : 'No se pudo agregar. Intenta de nuevo.'),
        ));
      }
    }
  }

  Future<void> _deleteEntry(String id) async {
    await Supabase.instance.client
        .from(AppConstants.tableLotteryEntries)
        .delete()
        .eq('id', id);
    ref.invalidate(myLotteryEntriesProvider);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final phase = ref.watch(lotteryPhaseProvider);
    final weekStart = ref.watch(lotteryWeekStartProvider);

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
                    Row(
                      children: [
                        Text('Sorteo semanal', style: AppTextStyles.headlineLg),
                        const Spacer(),
                        _PhaseChip(phase: phase),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _weekRangeLabel(weekStart),
                      style: AppTextStyles.bodyMd
                          .copyWith(color: AppColors.accentDeep.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverToBoxAdapter(child: _buildBody(weekStart)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(DateTime weekStart) {
    switch (_mode) {
      case _Mode.loading:
        return const SizedBox(height: 300,
            child: Center(child: CircularProgressIndicator()));
      case _Mode.open:
        return _OpenPhaseBody(
          weekStart: weekStart,
          onAdd: _addEntry,
          onDelete: _deleteEntry,
        );
      case _Mode.drawLoading:
        return const _DrawLoadingBody();
      case _Mode.countdown:
        return _CountdownBody(value: _countdownValue);
      case _Mode.revealing:
      case _Mode.resultsStatic:
        return _ResultsBody(
          entries: _entries,
          revealedCount: _mode == _Mode.resultsStatic ? _entries.length : _revealedCount,
        );
    }
  }

  String _weekRangeLabel(DateTime weekStart) {
    const months = ['ene','feb','mar','abr','may','jun',
        'jul','ago','sep','oct','nov','dic'];
    final end = weekStart.add(const Duration(days: 6));
    return '${weekStart.day} – ${end.day} de ${months[weekStart.month - 1]}';
  }
}

// ── Phase Chip ────────────────────────────────────────────────────────────

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.phase});
  final LotteryPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (phase) {
      LotteryPhase.open    => ('Inscripciones abiertas', AppColors.accentStrong),
      LotteryPhase.drawDay => ('Día del sorteo 🎲', AppColors.warning),
      LotteryPhase.results => ('Resultados', AppColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: AppTextStyles.labelSm.copyWith(color: color, fontSize: 11)),
    );
  }
}

// ── OPEN PHASE ────────────────────────────────────────────────────────────

class _OpenPhaseBody extends ConsumerWidget {
  const _OpenPhaseBody({
    required this.weekStart,
    required this.onAdd,
    required this.onDelete,
  });

  final DateTime weekStart;
  final Future<void> Function(String date, int hour) onAdd;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(myLotteryEntriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info banner
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.casino_rounded,
                    color: AppColors.accentDeep, size: 20),
                const SizedBox(width: 8),
                Text('¿Cómo funciona?', style: AppTextStyles.titleMd),
              ]),
              const SizedBox(height: 8),
              Text(
                'Elige hasta 3 horarios para la próxima semana. '
                'El viernes se sortea entre todos los interesados. '
                'Si hay competencia por un turno, uno queda al azar. '
                'Si solo tú lo pediste, te queda seguro.',
                style: AppTextStyles.bodyMd,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
          data: (entries) {
            final canAdd = entries.length < AppConstants.lotteryMaxEntries;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tus horarios elegidos (${entries.length}/${AppConstants.lotteryMaxEntries})',
                        style: AppTextStyles.titleLg),
                    if (canAdd)
                      TextButton.icon(
                        onPressed: () => _openPicker(context, weekStart, entries),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.accentDeep),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (entries.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      children: [
                        Container(
                          width: 56, height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.accentTint, shape: BoxShape.circle),
                          child: const Icon(Icons.confirmation_num_rounded,
                              color: AppColors.accentStrong, size: 28),
                        ),
                        const SizedBox(height: 14),
                        Text('Sin horarios elegidos',
                            style: AppTextStyles.titleLg,
                            textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text(
                          'Agrega hasta 3 horarios para participar en el sorteo del viernes.',
                          style: AppTextStyles.bodyMd,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        AppButton(
                          label: 'Elegir horario',
                          icon: Icons.add_rounded,
                          onPressed: () => _openPicker(context, weekStart, entries),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ...entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EntryTile(
                      entry: e,
                      onDelete: () => onDelete(e['id'] as String),
                    ),
                  )),
                  if (canAdd) ...[
                    const SizedBox(height: 4),
                    OutlinedButton.icon(
                      onPressed: () => _openPicker(context, weekStart, entries),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar otro horario'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentDeep,
                        side: const BorderSide(color: AppColors.accentSoft, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openPicker(BuildContext context, DateTime weekStart,
      List<Map<String, dynamic>> existing) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) =>
          _SlotPickerSheet(weekStart: weekStart, existingEntries: existing),
    );
    if (result != null) {
      await onAdd(result['slot_date'] as String, result['start_hour'] as int);
    }
  }
}

// ── Entry Tile ────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onDelete});
  final Map<String, dynamic> entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(entry['slot_date'] as String);
    final hour = entry['start_hour'] as int;
    const days = ['lun','mar','mié','jue','vie','sáb','dom'];
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final dayLabel = '${days[date.weekday - 1]} ${date.day} de ${months[date.month - 1]}';
    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      return '${h % 12 == 0 ? 12 : h % 12}:00 $ampm';
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.schedule_rounded,
              color: AppColors.accentDeep, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dayLabel, style: AppTextStyles.titleMd),
            Text('${fmt(hour)} – ${fmt(hour + 1)}', style: AppTextStyles.bodyMd),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppColors.error, size: 20),
          onPressed: onDelete,
        ),
      ]),
    );
  }
}

// ── Slot Picker Sheet ─────────────────────────────────────────────────────

class _SlotPickerSheet extends StatefulWidget {
  const _SlotPickerSheet({
    required this.weekStart,
    required this.existingEntries,
  });
  final DateTime weekStart;
  final List<Map<String, dynamic>> existingEntries;

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  DateTime? _selectedDay;

  List<DateTime> get _days =>
      List.generate(7, (i) => widget.weekStart.add(Duration(days: i)));

  bool _isSlotTaken(DateTime day, int hour) =>
      widget.existingEntries.any((e) =>
          e['slot_date'] == lotteryFmtDate(day) && e['start_hour'] == hour);

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'];
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final hours = List.generate(
      AppConstants.lastBookingHour - AppConstants.firstBookingHour + 1,
      (i) => AppConstants.firstBookingHour + i,
    );
    final weekEnd = widget.weekStart.add(const Duration(days: 6));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 5,
              decoration: BoxDecoration(color: AppColors.hair,
                  borderRadius: BorderRadius.circular(99)))),
          const SizedBox(height: 20),
          Text('Elige un horario', style: AppTextStyles.headlineSm),
          const SizedBox(height: 4),
          Text(
            'Semana del ${widget.weekStart.day} al ${weekEnd.day} de ${months[widget.weekStart.month - 1]}',
            style: AppTextStyles.bodyMd,
          ),
          const SizedBox(height: 20),

          Text('Día', style: AppTextStyles.labelMd),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (_, i) {
                final day = _days[i];
                final sel = _selectedDay != null &&
                    _selectedDay!.day == day.day &&
                    _selectedDay!.month == day.month;
                return GestureDetector(
                  onTap: () => setState(() => _selectedDay = day),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.accentStrong : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sel ? AppColors.accentStrong : AppColors.hair,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(dayNames[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : AppColors.textFaint,
                            )),
                        Text('${day.day}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : AppColors.textPrimary,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_selectedDay != null) ...[
            const SizedBox(height: 20),
            Text('Hora de inicio', style: AppTextStyles.labelMd),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: hours.map((h) {
                final taken = _isSlotTaken(_selectedDay!, h);
                String fmt(int hh) {
                  final ampm = hh < 12 ? 'am' : 'pm';
                  return '${hh % 12 == 0 ? 12 : hh % 12}:00$ampm';
                }
                return GestureDetector(
                  onTap: taken
                      ? null
                      : () => Navigator.pop(context, {
                            'slot_date': lotteryFmtDate(_selectedDay!),
                            'start_hour': h,
                          }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: taken
                          ? AppColors.background
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: taken ? AppColors.hair : AppColors.hair,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      fmt(h),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: taken
                            ? AppColors.textFaint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Draw Loading ──────────────────────────────────────────────────────────

class _DrawLoadingBody extends StatelessWidget {
  const _DrawLoadingBody();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _SpinningBalls(),
            const SizedBox(height: 28),
            Text('Realizando el sorteo...', style: AppTextStyles.titleLg),
            const SizedBox(height: 8),
            Text('Asignando horarios aleatoriamente',
                style: AppTextStyles.bodyMd),
          ],
        ),
      ),
    );
  }
}

class _SpinningBalls extends StatefulWidget {
  const _SpinningBalls();

  @override
  State<_SpinningBalls> createState() => _SpinningBallsState();
}

class _SpinningBallsState extends State<_SpinningBalls>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80, height: 80,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: List.generate(6, (i) {
              final angle = _ctrl.value * 2 * 3.14159 + (i * 2 * 3.14159 / 6);
              return Positioned(
                left: 40 + 28 * (0.5 * (angle % 6.28) < 3.14 ? 1 : -1) *
                    (0.7 + 0.3 * (i / 5)),
                top: 40 + 28 * (i % 3 == 0 ? -1 : i % 3 == 1 ? 0.5 : 1) * 0.7,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: [
                      AppColors.accentStrong,
                      AppColors.accentDeep,
                      AppColors.accentSoft,
                      AppColors.secondary,
                      AppColors.primary,
                      AppColors.accentTint,
                    ][i],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Countdown ─────────────────────────────────────────────────────────────

class _CountdownBody extends StatelessWidget {
  const _CountdownBody({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('El sorteo se revela en', style: AppTextStyles.titleLg),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Text(
                '$value',
                key: ValueKey(value),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 112,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentStrong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Results Body ──────────────────────────────────────────────────────────

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.entries, required this.revealedCount});
  final List<Map<String, dynamic>> entries;
  final int revealedCount;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          const Icon(Icons.inbox_rounded, color: AppColors.textFaint, size: 48),
          const SizedBox(height: 12),
          Text('No participaste este sorteo',
              style: AppTextStyles.titleLg, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('El sábado abre la inscripción para la próxima semana.',
              style: AppTextStyles.bodyMd, textAlign: TextAlign.center),
        ]),
      );
    }

    final allRevealed = revealedCount >= entries.length;
    final wonCount = entries.where((e) => e['status'] == 'won').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen — aparece cuando todo está revelado
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: allRevealed
              ? Padding(
                  key: const ValueKey('summary'),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: wonCount > 0 ? AppColors.accentTint : AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: wonCount > 0 ? AppColors.accentStrong : AppColors.hair,
                        width: 1.5,
                      ),
                    ),
                    child: Row(children: [
                      Text(wonCount > 0 ? '🎉' : '😅',
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              wonCount > 0
                                  ? 'Ganaste $wonCount ${wonCount == 1 ? 'horario' : 'horarios'}'
                                  : 'No quedaste esta vez',
                              style: AppTextStyles.titleLg.copyWith(
                                color: wonCount > 0
                                    ? AppColors.accentDeep
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              wonCount > 0
                                  ? 'Tus reservas ya aparecen en "Mis reservas".'
                                  : 'Intenta el próximo sábado.',
                              style: AppTextStyles.bodyMd,
                            ),
                          ],
                        ),
                      ),
                    ]),
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),

        // Tarjetas
        ...List.generate(entries.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ResultCard(
            entry: entries[i],
            revealed: i < revealedCount,
          ),
        )),
      ],
    );
  }
}

// ── Result Card ───────────────────────────────────────────────────────────

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.entry, required this.revealed});
  final Map<String, dynamic> entry;
  final bool revealed;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    if (widget.revealed) {
      _showContent = true;
      _ctrl.value = 1;
    }
  }

  @override
  void didUpdateWidget(_ResultCard old) {
    super.didUpdateWidget(old);
    if (widget.revealed && !old.revealed) {
      setState(() => _showContent = true);
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(widget.entry['slot_date'] as String);
    final hour = widget.entry['start_hour'] as int;
    final won = widget.entry['status'] == 'won';

    const days = ['lun','mar','mié','jue','vie','sáb','dom'];
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final dateLabel = '${days[date.weekday - 1]} ${date.day} de ${months[date.month - 1]}';

    String fmt(int h) {
      final ampm = h < 12 ? 'a.m.' : 'p.m.';
      return '${h % 12 == 0 ? 12 : h % 12}:00 $ampm';
    }

    // Mystery card
    if (!_showContent) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppColors.hair,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.help_outline_rounded,
                color: AppColors.textFaint, size: 24),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 130, height: 13,
                decoration: BoxDecoration(color: AppColors.hair,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 7),
            Container(width: 90, height: 11,
                decoration: BoxDecoration(color: AppColors.hair,
                    borderRadius: BorderRadius.circular(4))),
          ]),
        ]),
      );
    }

    // Revealed card
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: won ? AppColors.accentTint : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: won ? AppColors.accentStrong : AppColors.hair,
            width: won ? 2 : 1.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: won ? AppColors.accentStrong : AppColors.hair,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              won ? Icons.emoji_events_rounded : Icons.close_rounded,
              color: won ? Colors.white : AppColors.textFaint,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  won ? '¡Ganaste!' : 'No quedaste',
                  style: AppTextStyles.titleMd.copyWith(
                    color: won ? AppColors.accentDeep : AppColors.textSecondary,
                  ),
                ),
                Text('$dateLabel · ${fmt(hour)} – ${fmt(hour + 1)}',
                    style: AppTextStyles.bodyMd),
              ],
            ),
          ),
          if (won)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.accentStrong, size: 22),
        ]),
      ),
    );
  }
}
