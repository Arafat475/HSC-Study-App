import 'package:flutter/material.dart';

/// All the colors the app uses, as an object instead of top-level consts --
/// this is what makes light/dark switching possible, since a const Color
/// can never change at runtime but a field on a provided object can.
class AppColors {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color primary;
  final Color accent;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color danger;
  final Color success;
  final Color warning;

  const AppColors({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.primary,
    required this.accent,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
    required this.success,
    required this.warning,
  });

  /// The original neon dark palette, unchanged.
  static const AppColors dark = AppColors(
    isDark: true,
    background: Color(0xFF0E1013),
    surface: Color(0xFF181B21),
    surfaceAlt: Color(0xFF20242C),
    primary: Color(0xFF8B7CF6),
    accent: Color(0xFF2DD4BF),
    border: Color(0xFF2A2E38),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFF9AA0AC),
    textMuted: Color(0xFF666C78),
    danger: Color(0xFFEF5350),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
  );

  /// Light palette -- deeper accent tones than the dark version so they
  /// stay legible on white, and the neon glow effects are dropped in the
  /// screens that use them (glow reads as blur/mess on a light background,
  /// not "neon").
  static const AppColors light = AppColors(
    isDark: false,
    background: Color(0xFFF7F7FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0F0F5),
    primary: Color(0xFF6D5BD0),
    accent: Color(0xFF0F9488),
    border: Color(0xFFE2E4EA),
    textPrimary: Color(0xFF1A1D23),
    textSecondary: Color(0xFF5A5F6B),
    textMuted: Color(0xFF9096A3),
    danger: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    warning: Color(0xFFD97706),
  );

  static AppColors of(bool isDark) => isDark ? dark : light;
}
