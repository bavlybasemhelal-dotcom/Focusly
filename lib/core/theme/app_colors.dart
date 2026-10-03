import 'package:flutter/material.dart';

/// App color tokens with vibrant palettes for both Light and Dark modes.
class AppColors {
  // Shared Brand Colors
  static const Color primaryBlue = Color(0xFF2E6FF2);
  static const Color primaryBlueLight = Color(0xFF5B9BF5);
  static const Color primaryBlueVibrant = Color(0xFF2563EB);
  static const Color primaryBlueDark = Color(0xFF1E4FC7);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentGreenNeon = Color(0xFF4ADE80);
  static const Color cyanElectric = Color(0xFF00E5FF);
  static const Color cyanSky = Color(0xFF0EA5E9);
  static const Color amberGold = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);

  // Vibrant Light Palette (Daylight Glass & Aurora)
  static const Color lightBg = Color(0xFFF4F7FC);
  static const Color lightBgSecondary = Color(0xFFEEF3FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightGlass = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F5);
  static const Color lightBorderAccent = Color(0xFFDBEAFE);
  static const Color lightTextPrimary = Color(0xFF0B132B);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Palette (Midnight Neon Space)
  static const Color darkBg = Color(0xFF060B24);
  static const Color darkMidnight = Color(0xFF0B1647);
  static const Color darkSurface = Color(0xFF08123A);
  static const Color darkCard = Color(0xFF0F1B4C);
  static const Color darkBorder = Color(0xFF253449);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // Dynamic Theme Helpers
  static Color bg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBg : lightBg;

  static Color cardBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkCard : lightCard;

  static Color surfaceBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkSurface
      : lightSurface;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextPrimary
      : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkTextSecondary
      : lightTextSecondary;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.12)
      : lightBorder;

  static Color brandPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? cyanElectric
      : primaryBlueVibrant;

  static Color brandAccent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? accentGreenNeon
      : accentGreen;

  /// Dynamic Primary Button Gradient
  static LinearGradient primaryGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF1E58F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
  }

  /// Dynamic Card Shadow
  static List<BoxShadow> cardShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF2E6FF2).withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ];
  }
}
