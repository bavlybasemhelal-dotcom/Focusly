import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Modern ThemeData builders for Focusly Light & Dark modes.
class AppTheme {
  /// Light Mode Theme (Vibrant, Frosted Glass, Daylight Aurora)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlueVibrant,
        secondary: AppColors.accentGreen,
        surface: AppColors.lightSurface,
        error: AppColors.errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        hourMinuteColor: const Color(0xFFEFF6FF),
        hourMinuteTextColor: AppColors.primaryBlueVibrant,
        dialHandColor: AppColors.primaryBlueVibrant,
        dialBackgroundColor: const Color(0xFFF1F5F9),
        dialTextColor: AppColors.lightTextPrimary,
        entryModeIconColor: AppColors.primaryBlueVibrant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
      ),
    );
  }

  /// Dark Mode Theme (Midnight Neon Space)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyanElectric,
        secondary: AppColors.accentGreenNeon,
        surface: AppColors.darkMidnight,
        error: AppColors.errorRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: const Color(0xFF0F1B4C),
        hourMinuteColor: const Color(0xFF08123A),
        hourMinuteTextColor: AppColors.cyanElectric,
        dialHandColor: AppColors.cyanElectric,
        dialBackgroundColor: const Color(0xFF060B24),
        dialTextColor: Colors.white,
        entryModeIconColor: AppColors.cyanElectric,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
    );
  }
}
