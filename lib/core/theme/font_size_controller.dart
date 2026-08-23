import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enum representing the supported user-selectable font sizes.
enum AppFontSize {
  small(scaleFactor: 0.88, storageKey: 'small', titleKey: 'font_size_small'),
  standard(scaleFactor: 1.00, storageKey: 'standard', titleKey: 'font_size_standard'),
  large(scaleFactor: 1.15, storageKey: 'large', titleKey: 'font_size_large');

  final double scaleFactor;
  final String storageKey;
  final String titleKey;

  const AppFontSize({
    required this.scaleFactor,
    required this.storageKey,
    required this.titleKey,
  });

  static AppFontSize fromKey(String? key) {
    switch (key) {
      case 'small':
        return AppFontSize.small;
      case 'large':
        return AppFontSize.large;
      case 'standard':
      default:
        return AppFontSize.standard;
    }
  }
}

/// State notifier that manages the app-wide font size / text scale factor.
/// Persists the selected option to [SharedPreferences] across app sessions.
class FontSizeController extends Notifier<AppFontSize> {
  static const String _prefKey = 'focusly_app_font_size';

  @override
  AppFontSize build() {
    // Initial default is standard
    _loadSavedFontSize();
    return AppFontSize.standard;
  }

  /// Asynchronously loads saved font size preference from SharedPreferences
  Future<void> _loadSavedFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefKey);
      if (savedKey != null) {
        state = AppFontSize.fromKey(savedKey);
      }
    } catch (_) {
      // Fallback silently during tests or uninitialized storage
    }
  }

  /// Updates and persists the user's chosen font size scale factor
  Future<void> setFontSize(AppFontSize fontSize) async {
    state = fontSize;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, fontSize.storageKey);
    } catch (_) {}
  }
}

/// Global provider for accessing and updating the app-wide font size scale
final fontSizeControllerProvider =
    NotifierProvider<FontSizeController, AppFontSize>(() {
  return FontSizeController();
});
