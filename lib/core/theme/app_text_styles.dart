import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get _jakarta => GoogleFonts.plusJakartaSans();

  static TextStyle get displayLg => _jakarta.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLg => _jakarta.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMd => _jakarta.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineSm => _jakarta.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLg => _jakarta.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMd => _jakarta.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLg => _jakarta.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodyMd => _jakarta.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelLg => _jakarta.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMd => _jakarta.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get labelSm => _jakarta.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textFaint,
      );

  static TextStyle get caption => _jakarta.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textFaint,
      );
}
