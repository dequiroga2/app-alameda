import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({
    super.key,
    required this.reservationId,
    required this.amenityName,
    required this.date,
    required this.hour,
  });

  final String reservationId;
  final String amenityName;
  final DateTime date;
  final int hour;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Cubic(0.2, 1.3, 0.4, 1.0),
    );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    // Pequeño delay para que el usuario vea la pantalla antes del pop
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Ícono animado con bounce
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: ScaleTransition(
                          scale: _scaleAnim,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.accentStrong,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentSoft.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 52,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      Text(
                        '¡Reserva confirmada!',
                        style: AppTextStyles.headlineLg,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Te esperamos en la ${widget.amenityName.toLowerCase()}.\nTe enviaremos un recordatorio.',
                        style: AppTextStyles.bodyLg,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // Tarjeta resumen
                      AppCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            // Mini calendario visual
                            Container(
                              width: 58,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.accentTint,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _shortDay(widget.date),
                                    style: AppTextStyles.labelSm.copyWith(
                                        color: AppColors.accentDeep,
                                        fontSize: 11),
                                  ),
                                  Text(
                                    '${widget.date.day}',
                                    style: AppTextStyles.headlineLg.copyWith(
                                        color: AppColors.accentDeep,
                                        fontSize: 28),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.amenityName,
                                      style: AppTextStyles.titleLg),
                                  const SizedBox(height: 3),
                                  Text(
                                    _longDate(widget.date),
                                    style: AppTextStyles.bodyMd,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _fmtRange(widget.hour),
                                    style: AppTextStyles.labelLg.copyWith(
                                        color: AppColors.accentDeep),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botón de listo
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bot + 16),
              child: AppButton(
                label: 'Listo',
                onPressed: () => context.go('/my-reservations'),
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortDay(DateTime d) {
    const days = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB'];
    return days[d.weekday % 7];
  }

  String _longDate(DateTime d) {
    const days = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
    const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio',
        'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    final day = days[d.weekday % 7];
    return '${day[0].toUpperCase()}${day.substring(1)} ${d.day} de ${months[d.month - 1]}';
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
