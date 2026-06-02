import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Wave header — estilo de los archivos adjuntos (minimalista con ola orgánica).
/// El gradiente va de accentTint → accentSoft en modo suave,
/// o de accentStrong → accentDeep en modo sólido (como en Login).
class WaveHeader extends StatelessWidget {
  const WaveHeader({
    super.key,
    required this.child,
    this.solid = false,
    this.height,
    this.backgroundColor,
  });

  final Widget child;
  final bool solid;
  final double? height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.background;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fondo con gradiente
        Container(
          decoration: BoxDecoration(
            gradient: solid
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentStrong, AppColors.accentDeep],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.accentTint, AppColors.accentSoft],
                    stops: [0.0, 1.3],
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              child,
              const SizedBox(height: 38), // espacio para la ola
            ],
          ),
        ),
        // Ola orgánica en la parte inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: const Size(double.infinity, 48),
            painter: _WavePainter(color: bg),
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..cubicTo(
        size.width * 0.22, size.height * 1.1,
        size.width * 0.38, size.height * 0.1,
        size.width * 0.57, size.height * 0.42,
      )
      ..cubicTo(
        size.width * 0.77, size.height * 0.72,
        size.width * 0.87, size.height * 1.0,
        size.width, size.height * 0.52,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.color != color;
}
