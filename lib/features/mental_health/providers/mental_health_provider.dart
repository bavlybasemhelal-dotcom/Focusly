import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/mental_health_helpers.dart';
import '../models/mental_log_model.dart';
import '../services/mental_health_service.dart';

/// Active radar chart view mode: Daily single-day check-in vs Weekly calendar average.
enum MentalViewMode {
  daily,
  weekly,
}

/// Notifier controller for selected date (defaults to today).
class MentalSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return MentalHealthHelpers.toDateOnly(DateTime.now());
  }

  void setDate(DateTime date) {
    state = MentalHealthHelpers.toDateOnly(date);
  }
}

/// Provider for selected date in Mental Health feature.
final mentalSelectedDateProvider =
    NotifierProvider<MentalSelectedDateNotifier, DateTime>(
  MentalSelectedDateNotifier.new,
);

/// Notifier controller for MentalViewMode (Daily vs Weekly).
class MentalViewModeNotifier extends Notifier<MentalViewMode> {
  @override
  MentalViewMode build() {
    return MentalViewMode.daily;
  }

  void setMode(MentalViewMode mode) {
    state = mode;
  }
}

/// Provider for view mode in Mental Health feature.
final mentalViewModeProvider =
    NotifierProvider<MentalViewModeNotifier, MentalViewMode>(
  MentalViewModeNotifier.new,
);

/// Service singleton provider.
final mentalHealthServiceProvider = Provider<MentalHealthService>((ref) {
  return MentalHealthService();
});

/// Stream provider for all mental health logs belonging to the authenticated user.
/// Scoped to `users/{uid}/mentalLog`.
final mentalLogsStreamProvider = StreamProvider<List<MentalLogModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(mentalHealthServiceProvider);
  return service.streamMentalLogs(uid);
});

/// Derived provider: The mental log matching the currently selected date.
final selectedDayMentalLogProvider = Provider<MentalLogModel?>((ref) {
  final logs = ref.watch(mentalLogsStreamProvider).value ?? [];
  final selectedDate = ref.watch(mentalSelectedDateProvider);
  final targetKey = MentalHealthHelpers.formatDateKey(selectedDate);

  try {
    return logs.firstWhere((l) => l.weekOf == targetKey);
  } catch (_) {
    return null;
  }
});

/// Derived provider: The mental log matching yesterday relative to selected date.
final yesterdayMentalLogProvider = Provider<MentalLogModel?>((ref) {
  final logs = ref.watch(mentalLogsStreamProvider).value ?? [];
  final selectedDate = ref.watch(mentalSelectedDateProvider);
  final yesterday = selectedDate.subtract(const Duration(days: 1));
  final yesterdayKey = MentalHealthHelpers.formatDateKey(yesterday);

  try {
    return logs.firstWhere((l) => l.weekOf == yesterdayKey);
  } catch (_) {
    return null;
  }
});

/// Derived provider: The weekly average mental log for the selected date's calendar week.
final selectedWeekAverageLogProvider = Provider<MentalLogModel?>((ref) {
  final logs = ref.watch(mentalLogsStreamProvider).value ?? [];
  final selectedDate = ref.watch(mentalSelectedDateProvider);
  return MentalHealthHelpers.computeWeeklyAverage(logs, selectedDate);
});

/// Derived provider: Active log to display (Daily log in daily mode, Weekly average in weekly mode).
final activeDisplayMentalLogProvider = Provider<MentalLogModel?>((ref) {
  final mode = ref.watch(mentalViewModeProvider);
  if (mode == MentalViewMode.daily) {
    return ref.watch(selectedDayMentalLogProvider);
  } else {
    return ref.watch(selectedWeekAverageLogProvider);
  }
});

/// Derived provider: Lowest-scoring dimension and personalized tip.
final personalizedTipProvider = Provider<LowestDimensionTip?>((ref) {
  final allLogs = ref.watch(mentalLogsStreamProvider).value ?? [];
  final currentLog = ref.watch(activeDisplayMentalLogProvider);
  return MentalHealthHelpers.findLowestDimension(
    currentDisplayLog: currentLog,
    allLogs: allLogs,
  );
});

/// Derived provider: Today vs Yesterday comparison (only applicable when daily log exists).
final todayVsYesterdayComparisonProvider = Provider<TodayVsYesterdayComparison?>((ref) {
  final todayLog = ref.watch(selectedDayMentalLogProvider);
  if (todayLog == null) return null;

  final yesterdayLog = ref.watch(yesterdayMentalLogProvider);
  return MentalHealthHelpers.compareTodayVsYesterday(
    todayLog: todayLog,
    yesterdayLog: yesterdayLog,
  );
});
