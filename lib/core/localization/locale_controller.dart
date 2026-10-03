import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefLocaleKey = 'app_selected_locale_code';

/// Riverpod controller managing app-wide language locale with persistent storage.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _loadSavedLocale();
    return const Locale('en');
  }

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedCode = prefs.getString(kPrefLocaleKey);
      if (savedCode != null && (savedCode == 'en' || savedCode == 'ar')) {
        state = Locale(savedCode);
      }
    } catch (_) {}
  }

  /// Sets the app locale ('en' or 'ar') and persists selection
  Future<void> setLocale(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'ar') return;
    state = Locale(languageCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPrefLocaleKey, languageCode);
    } catch (_) {}
  }

  /// Toggles between English and Arabic
  Future<void> toggleLocale() async {
    final nextCode = state.languageCode == 'en' ? 'ar' : 'en';
    await setLocale(nextCode);
  }
}

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);
