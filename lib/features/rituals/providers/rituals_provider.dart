import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/ritual_model.dart';
import '../services/rituals_service.dart';

/// Provider for RitualsService singleton.
final ritualsServiceProvider = Provider<RitualsService>((ref) {
  return RitualsService();
});

/// Provider for today's date formatted as `YYYY-MM-DD`.
final todayDateStringProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
});

/// Stream provider for today's ritual document.
final todayRitualStreamProvider = StreamProvider<RitualModel?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final dateStr = ref.watch(todayDateStringProvider);
  final service = ref.watch(ritualsServiceProvider);
  return service.streamTodayRitual(uid, dateStr);
});

/// Stream provider for all past rituals.
final ritualsHistoryStreamProvider = StreamProvider<List<RitualModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(ritualsServiceProvider);
  return service.streamRituals(uid);
});

/// Persisted state tracking if the morning intention prompt/banner was already shown or dismissed today.
///
/// ROOT CAUSE & PERSISTENCE NOTE:
/// Previously:
/// 1. `build()` synchronously returned `false` while `_load()` was an unawaited Future, causing
///    initial checks on app launch to read `false` before disk I/O finished.
/// 2. Saving an intention called `.reset()`, deleting the date key and causing re-prompts on restart.
/// We now:
/// - Check the persisted calendar date string (`YYYY-MM-DD`) asynchronously via `hasBeenShownToday()`.
/// - Sync the prompt record to Firestore as well as SharedPreferences.
/// - Maintain the 'shown today' status across saves, dismissals, and app restarts.
class MorningIntentionDismissedNotifier extends Notifier<bool> {
  static const _key = 'setting_morning_intention_last_prompt_date';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final isShown = await hasBeenShownToday();
    state = isShown;
  }

  /// Asynchronously checks if the prompt was already shown or dismissed today by comparing
  /// the stored calendar date (`YYYY-MM-DD`) against today's calendar date.
  Future<bool> hasBeenShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_key);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final isShown = lastDate == today;
    if (state != isShown) {
      state = isShown;
    }
    return isShown;
  }

  /// Marks the prompt as dismissed for today and persists today's date.
  Future<void> dismiss() async {
    await markShownToday();
  }

  /// Marks the prompt as already shown today so it doesn't pop up again today.
  Future<void> markShownToday() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setString(_key, today);

    // Sync to Firestore for multi-device consistency
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await ref.read(ritualsServiceProvider).recordPromptShown(uid, today);
      }
    } catch (e) {
      debugPrint('Error syncing prompt date to Firestore: $e');
    }
  }

  /// Resets the prompt state (clearing the stored date).
  Future<void> reset() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final morningIntentionDismissedProvider =
    NotifierProvider<MorningIntentionDismissedNotifier, bool>(
      MorningIntentionDismissedNotifier.new,
    );

/// Preference notifier for auto-prompting Morning Intention on Home screen load.
class MorningIntentionPromptSettingNotifier extends Notifier<bool> {
  static const _key = 'setting_morning_intention_prompt';

  @override
  bool build() {
    _load();
    return true; // Default enabled
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final morningIntentionPromptSettingProvider =
    NotifierProvider<MorningIntentionPromptSettingNotifier, bool>(
      MorningIntentionPromptSettingNotifier.new,
    );

/// Preference notifier for Preferred Shutdown Time (default 22:00 / 10:00 PM).
class PreferredShutdownTimeSettingNotifier extends Notifier<TimeOfDay> {
  static const _hourKey = 'setting_preferred_shutdown_hour';
  static const _minuteKey = 'setting_preferred_shutdown_minute';

  @override
  TimeOfDay build() {
    _load();
    return const TimeOfDay(hour: 22, minute: 0); // Default 10:00 PM
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_hourKey) ?? 22;
    final minute = prefs.getInt(_minuteKey) ?? 0;
    state = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> setTime(TimeOfDay time) async {
    state = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minuteKey, time.minute);
  }
}

final preferredShutdownTimeSettingProvider =
    NotifierProvider<PreferredShutdownTimeSettingNotifier, TimeOfDay>(
      PreferredShutdownTimeSettingNotifier.new,
    );
