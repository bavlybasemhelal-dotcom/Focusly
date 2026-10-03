import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/data/calendar_clock.dart';
import '../models/checkin_model.dart';
import '../services/energy_mood_service.dart';

/// Provider exposing the singleton EnergyMoodService.
final energyMoodServiceProvider = Provider<EnergyMoodService>((ref) {
  return EnergyMoodService();
});

/// Real-time stream provider for today's check-in.
final todayCheckinStreamProvider = StreamProvider<CheckinModel?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(null);
  }
  final service = ref.watch(energyMoodServiceProvider);
  final date = EnergyMoodService.formatDate(ref.watch(calendarClockProvider));
  return service.streamCheckinForDate(uid, date);
});

/// Family stream provider for checking in on any specific date "YYYY-MM-DD".
final checkinForDateStreamProvider =
    StreamProvider.family<CheckinModel?, String>((ref, dateStr) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null || uid.isEmpty) {
        return Stream.value(null);
      }
      final service = ref.watch(energyMoodServiceProvider);
      return service.streamCheckinForDate(uid, dateStr);
    });

/// Stream provider for all past check-ins for the history page and charts.
final checkinsHistoryStreamProvider = StreamProvider<List<CheckinModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(energyMoodServiceProvider);
  return service.streamCheckinsHistory(uid, limit: 60);
});

/// Notifier managing the user's daily water target (glasses).
class DailyWaterTargetNotifier extends Notifier<int> {
  static const String _prefKey = 'pref_daily_water_target';
  static const int defaultTarget = 8;

  @override
  int build() {
    final uid = ref.watch(currentUserIdProvider);
    _load(uid);
    return defaultTarget;
  }

  Future<void> _load(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('${_prefKey}_${uid ?? 'signed_out'}');
      if (ref.mounted &&
          ref.read(currentUserIdProvider) == uid &&
          saved != null &&
          saved > 0) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setTarget(int target) async {
    if (target < 1) target = 1;
    if (target > 30) target = 30;
    final uid = ref.read(currentUserIdProvider);
    state = target;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('${_prefKey}_${uid ?? 'signed_out'}', target);
    } catch (_) {}
  }
}

final dailyWaterTargetProvider =
    NotifierProvider<DailyWaterTargetNotifier, int>(
      DailyWaterTargetNotifier.new,
    );

/// Notifier managing whether the daily check-in reminder banner shows on Home screen.
class DailyCheckinReminderNotifier extends Notifier<bool> {
  static const String _prefKey = 'pref_daily_checkin_reminder';

  @override
  bool build() {
    final uid = ref.watch(currentUserIdProvider);
    _load(uid);
    return true;
  }

  Future<void> _load(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('${_prefKey}_${uid ?? 'signed_out'}');
      if (ref.mounted &&
          ref.read(currentUserIdProvider) == uid &&
          saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    final uid = ref.read(currentUserIdProvider);
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('${_prefKey}_${uid ?? 'signed_out'}', enabled);
    } catch (_) {}
  }
}

final dailyCheckinReminderProvider =
    NotifierProvider<DailyCheckinReminderNotifier, bool>(
      DailyCheckinReminderNotifier.new,
    );
