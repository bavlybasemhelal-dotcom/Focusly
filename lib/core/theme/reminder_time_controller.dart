import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State notifier that manages the user's default daily reminder time.
/// Persists the selected [TimeOfDay] (hour and minute) to [SharedPreferences].
///
/// TODO: In the upcoming notifications release, wire this controller with
/// Flutter Local Notifications / Firebase Cloud Messaging to trigger daily
/// habit & task reminder alerts at the specified [TimeOfDay].
class ReminderTimeController extends Notifier<TimeOfDay> {
  static const String _prefHourKey = 'focusly_reminder_hour';
  static const String _prefMinuteKey = 'focusly_reminder_minute';

  @override
  TimeOfDay build() {
    // Default reminder time is 09:00 AM
    _loadSavedReminderTime();
    return const TimeOfDay(hour: 9, minute: 0);
  }

  /// Loads saved reminder hour and minute from SharedPreferences
  Future<void> _loadSavedReminderTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedHour = prefs.getInt(_prefHourKey);
      final savedMinute = prefs.getInt(_prefMinuteKey);
      if (savedHour != null && savedMinute != null) {
        state = TimeOfDay(hour: savedHour, minute: savedMinute);
      }
    } catch (_) {
      // Safe fallback if offline or during testing
    }
  }

  /// Sets and persists the new reminder time
  Future<void> setReminderTime(TimeOfDay time) async {
    state = time;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefHourKey, time.hour);
      await prefs.setInt(_prefMinuteKey, time.minute);
    } catch (_) {}
  }

  /// Formats the current time into a clean 12-hour string (e.g. "09:00 AM")
  String formatTime(BuildContext context) {
    return state.format(context);
  }
}

/// Global provider for accessing and updating the default daily reminder time
final reminderTimeControllerProvider =
    NotifierProvider<ReminderTimeController, TimeOfDay>(() {
  return ReminderTimeController();
});
