import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

enum AppButtonVariant { primary, soft, secondary, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = _colors();
    final (vPad, fontSize) = _sizing();
    final isDisabled = onPressed == null || loading;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          backgroundColor: isDisabled ? bg.withValues(alpha: 0.4) : bg,
          foregroundColor: fg,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: vPad),
          shape: const StadiumBorder(),
          side: border != null ? BorderSide(color: border, width: 1.5) : null,
          minimumSize: Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: fg,
                ),
              )
            : Row(
                mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: fontSize + 4, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: isDisabled ? fg.withValues(alpha: 0.6) : fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  (Color, Color, Color?) _colors() => switch (variant) {
        AppButtonVariant.primary => (AppColors.accentStrong, Colors.white, null),
        AppButtonVariant.soft => (AppColors.accentTint, AppColors.accentDeep, null),
        AppButtonVariant.secondary => (AppColors.surface, AppColors.textPrimary, AppColors.hair),
        AppButtonVariant.ghost => (Colors.transparent, AppColors.accentDeep, null),
        AppButtonVariant.danger => (AppColors.errorTint, AppColors.error, null),
      };

  (double, double) _sizing() => switch (size) {
        AppButtonSize.sm => (10.0, 14.0),
        AppButtonSize.md => (14.0, 16.0),
        AppButtonSize.lg => (17.0, 18.0),
      };
}
