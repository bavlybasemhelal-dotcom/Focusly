import '../models/workout_model.dart';

/// Summary metrics for workout duration and calorie burn over the past 7 days.
class WorkoutStats {
  final int thisWeekMinutes;
  final int thisWeekCalories;
  final int totalWorkoutsCount;

  const WorkoutStats({
    required this.thisWeekMinutes,
    required this.thisWeekCalories,
    required this.totalWorkoutsCount,
  });
}

/// Day entry container for the 30-day streak heatmap grid.
class HeatmapDayInfo {
  final DateTime date;
  final int dayIndex; // 0 to 29 (29 is today)
  final bool hasWorkout;
  final int workoutCount;
  final int totalDurationMin;
  final int totalCalories;

  const HeatmapDayInfo({
    required this.date,
    required this.dayIndex,
    required this.hasWorkout,
    required this.workoutCount,
    required this.totalDurationMin,
    required this.totalCalories,
  });
}

/// Pure helper functions for Workout Tracker calculations and heatmap generation.
class WorkoutHelpers {
  /// Computes this week's (last 7 calendar days) total minutes and calories.
  static WorkoutStats calculateStats(List<WorkoutModel> workouts, [DateTime? now]) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    final weekStart = todayStart.subtract(const Duration(days: 6)); // 7 days total including today

    int weekMinutes = 0;
    int weekCalories = 0;

    for (final w in workouts) {
      final wDate = DateTime(w.date.year, w.date.month, w.date.day);
      if (wDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
          wDate.isBefore(todayStart.add(const Duration(days: 1)))) {
        weekMinutes += w.durationMin;
        weekCalories += w.calories;
      }
    }

    return WorkoutStats(
      thisWeekMinutes: weekMinutes,
      thisWeekCalories: weekCalories,
      totalWorkoutsCount: workouts.length,
    );
  }

  /// Generates a 30-day chronological list of [HeatmapDayInfo] ending with today.
  static List<HeatmapDayInfo> compute30DayHeatmap(
    List<WorkoutModel> workouts, [
    DateTime? now,
  ]) {
    final current = now ?? DateTime.now();
    final todayStart = DateTime(current.year, current.month, current.day);
    final List<HeatmapDayInfo> result = [];

    for (int i = 29; i >= 0; i--) {
      final targetDate = todayStart.subtract(Duration(days: i));
      final dayIndex = 29 - i; // 0 for 29 days ago, 29 for today

      // Find workouts matching this calendar day
      final matching = workouts.where((w) {
        return w.date.year == targetDate.year &&
            w.date.month == targetDate.month &&
            w.date.day == targetDate.day;
      }).toList();

      final count = matching.length;
      final duration = matching.fold<int>(0, (sum, w) => sum + w.durationMin);
      final calories = matching.fold<int>(0, (sum, w) => sum + w.calories);

      result.add(
        HeatmapDayInfo(
          date: targetDate,
          dayIndex: dayIndex,
          hasWorkout: count > 0,
          workoutCount: count,
          totalDurationMin: duration,
          totalCalories: calories,
        ),
      );
    }

    return result;
  }
}
