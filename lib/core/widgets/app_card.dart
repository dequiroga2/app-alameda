import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? 20.0;
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(18),
      child: child,
    );

    return Material(
      color: color ?? AppColors.surface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.hair),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A1E2A23),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
              BoxShadow(
                color: Color(0x0D1E2A23),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}
