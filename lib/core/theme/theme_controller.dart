import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefThemeModeKey = 'app_selected_theme_mode';

/// Riverpod controller managing app-wide theme mode (Light, Dark, System)
/// with persistent storage in SharedPreferences.
class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadSavedThemeMode();
    return ThemeMode.system;
  }

  Future<void> _loadSavedThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? saved = prefs.getString(kPrefThemeModeKey);
      if (saved != null) {
        switch (saved) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          default:
            state = ThemeMode.system;
        }
      }
    } catch (_) {}
  }

  /// Sets theme mode and persists to SharedPreferences
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val;
      switch (mode) {
        case ThemeMode.light:
          val = 'light';
          break;
        case ThemeMode.dark:
          val = 'dark';
          break;
        case ThemeMode.system:
          val = 'system';
          break;
      }
      await prefs.setString(kPrefThemeModeKey, val);
    } catch (_) {}
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);
