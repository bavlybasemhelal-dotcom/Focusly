import '../../../core/data/calendar_clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../energy_mood/providers/energy_mood_provider.dart';
import '../../goals/providers/goals_provider.dart';
import '../../habits/providers/habits_provider.dart';
import '../../reading_tracker/providers/reading_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../helpers/life_score_calculator.dart';
import '../models/life_score_model.dart';
import '../services/life_score_service.dart';

/// Provider for LifeScoreService
final lifeScoreServiceProvider = Provider<LifeScoreService>((ref) {
  return LifeScoreService();
});

/// Stream provider for all persistent life score snapshots for the user
final lifeScoreLogsStreamProvider = StreamProvider<List<LifeScoreModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return Stream.value([]);
  final service = ref.watch(lifeScoreServiceProvider);
  return service.streamLifeScoreLogs(uid);
});

/// Computes the start date (Sunday) of the active current week
final currentWeekStartProvider = Provider<DateTime>((ref) {
  return LifeScoreCalculator.getWeekStart(ref.watch(calendarClockProvider));
});

/// Notifier managing the selected week start date for historical navigation
class SelectedWeekNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return LifeScoreCalculator.getWeekStart(DateTime.now());
  }

  void setWeek(DateTime weekStart) {
    state = LifeScoreCalculator.getWeekStart(weekStart);
  }

  void previousWeek() {
    state = state.subtract(const Duration(days: 7));
  }

  void nextWeek() {
    state = state.add(const Duration(days: 7));
  }

  void resetToCurrentWeek() {
    state = LifeScoreCalculator.getWeekStart(DateTime.now());
  }
}

final selectedWeekStartProvider =
    NotifierProvider<SelectedWeekNotifier, DateTime>(SelectedWeekNotifier.new);

/// Derived provider that computes the LIVE Life Score for the CURRENT week
/// across all 5 active data streams.
final currentLiveLifeScoreProvider = Provider<LifeScoreModel>((ref) {
  final weekStart = ref.watch(currentWeekStartProvider);
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final habits = ref.watch(habitsStreamProvider).value ?? [];
  final checkins = ref.watch(checkinsHistoryStreamProvider).value ?? [];
  final books = ref.watch(booksStreamProvider).value ?? [];
  final goals = ref.watch(goalsStreamProvider).value ?? [];

  return LifeScoreCalculator.computeLifeScore(
    weekStart: weekStart,
    tasks: tasks,
    habits: habits,
    checkins: checkins,
    books: books,
    goals: goals,
    isCurrentWeek: true,
  );
});

/// State evaluation for the currently selected week:
/// - If current week: returns the live recomputed score.
/// - If past week: looks up stored snapshot from Firestore.
final selectedWeekLifeScoreProvider = Provider<LifeScoreModel?>((ref) {
  final selectedWeek = ref.watch(selectedWeekStartProvider);
  final currentWeek = ref.watch(currentWeekStartProvider);

  final bool isCurrent =
      selectedWeek.year == currentWeek.year &&
      selectedWeek.month == currentWeek.month &&
      selectedWeek.day == currentWeek.day;

  if (isCurrent) {
    return ref.watch(currentLiveLifeScoreProvider);
  }

  final weekId = LifeScoreCalculator.formatWeekId(selectedWeek);
  final logs = ref.watch(lifeScoreLogsStreamProvider).value ?? [];

  try {
    return logs.firstWhere((l) => l.weekOf == weekId);
  } catch (_) {
    return null;
  }
});
