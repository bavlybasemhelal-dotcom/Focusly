import '../../energy_mood/models/checkin_model.dart';
import '../../tasks/models/task_model.dart';

/// Container for Energy Impact on Productivity analytics.
class EnergyProductivityImpact {
  final double avgHigh; // Energy >= 4
  final double avgLow; // Energy <= 2
  final int highDaysCount;
  final int lowDaysCount;

  const EnergyProductivityImpact({
    required this.avgHigh,
    required this.avgLow,
    required this.highDaysCount,
    required this.lowDaysCount,
  });

  String get formattedAvgHigh => avgHigh.toStringAsFixed(1);
  String get formattedAvgLow => avgLow.toStringAsFixed(1);
}

/// Container for Most Productive Day of Week analytics.
class MostProductiveDayResult {
  final int dayOfWeek; // 1 (Mon) to 7 (Sun)
  final String dayNameKey; // e.g. 'day_monday', 'day_sunday'
  final int completedTasksCount;
  final bool hasCompletedTasks;

  const MostProductiveDayResult({
    required this.dayOfWeek,
    required this.dayNameKey,
    required this.completedTasksCount,
    required this.hasCompletedTasks,
  });
}

/// Overall Life Analytics computation container.
class LifeAnalyticsSummary {
  final bool hasCheckins;
  final int totalCheckins;
  final EnergyProductivityImpact energyImpact;
  final MostProductiveDayResult mostProductiveDay;

  const LifeAnalyticsSummary({
    required this.hasCheckins,
    required this.totalCheckins,
    required this.energyImpact,
    required this.mostProductiveDay,
  });
}

/// Pure calculation functions for Life Analytics without Firestore dependencies.
class LifeAnalyticsHelpers {
  /// Normalizes date to `YYYY-MM-DD` string.
  static String formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Maps Dart's DateTime.weekday (1=Mon ... 7=Sun) to translation key.
  static String getDayTranslationKey(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return 'day_sunday';
      case DateTime.monday:
        return 'day_monday';
      case DateTime.tuesday:
        return 'day_tuesday';
      case DateTime.wednesday:
        return 'day_wednesday';
      case DateTime.thursday:
        return 'day_thursday';
      case DateTime.friday:
        return 'day_friday';
      case DateTime.saturday:
        return 'day_saturday';
      default:
        return 'day_sunday';
    }
  }

  /// Computes the average tasks completed on high-energy (>= 4) vs low-energy (<= 2) days.
  static EnergyProductivityImpact computeEnergyProductivityImpact({
    required List<CheckinModel> checkins,
    required List<TaskModel> tasks,
  }) {
    if (checkins.isEmpty) {
      return const EnergyProductivityImpact(
        avgHigh: 0.0,
        avgLow: 0.0,
        highDaysCount: 0,
        lowDaysCount: 0,
      );
    }

    // 1. Group completed tasks by their completion date string "YYYY-MM-DD"
    final completedTasksByDate = <String, int>{};
    for (final task in tasks) {
      if (task.done) {
        final completionDate = task.doneAt ?? task.date;
        final dateKey = formatDateKey(completionDate);
        completedTasksByDate[dateKey] =
            (completedTasksByDate[dateKey] ?? 0) + 1;
      }
    }

    // 2. Tally tasks on high-energy days (>= 4) and low-energy days (<= 2)
    int highDaysCount = 0;
    int highTasksTotal = 0;

    int lowDaysCount = 0;
    int lowTasksTotal = 0;

    for (final checkin in checkins) {
      final dateKey = checkin.date;
      final tasksOnDate = completedTasksByDate[dateKey] ?? 0;

      if (checkin.energy >= 4) {
        highDaysCount++;
        highTasksTotal += tasksOnDate;
      } else if (checkin.energy <= 2) {
        lowDaysCount++;
        lowTasksTotal += tasksOnDate;
      }
    }

    final double avgHigh = highDaysCount > 0
        ? ((highTasksTotal / highDaysCount) * 10).round() / 10.0
        : 0.0;

    final double avgLow = lowDaysCount > 0
        ? ((lowTasksTotal / lowDaysCount) * 10).round() / 10.0
        : 0.0;

    return EnergyProductivityImpact(
      avgHigh: avgHigh,
      avgLow: avgLow,
      highDaysCount: highDaysCount,
      lowDaysCount: lowDaysCount,
    );
  }

  /// Tallies completed tasks across days of the week (Sun-Sat) and finds the most productive day.
  static MostProductiveDayResult computeMostProductiveDay(
    List<TaskModel> tasks,
  ) {
    final completedTasks = tasks.where((t) => t.done).toList();
    if (completedTasks.isEmpty) {
      return const MostProductiveDayResult(
        dayOfWeek: DateTime.sunday,
        dayNameKey: 'day_sunday',
        completedTasksCount: 0,
        hasCompletedTasks: false,
      );
    }

    // Tallies per weekday (1=Mon ... 7=Sun)
    final weekdayTallies = <int, int>{
      DateTime.sunday: 0,
      DateTime.monday: 0,
      DateTime.tuesday: 0,
      DateTime.wednesday: 0,
      DateTime.thursday: 0,
      DateTime.friday: 0,
      DateTime.saturday: 0,
    };

    for (final task in completedTasks) {
      final completionDate = task.doneAt ?? task.date;
      final weekday = completionDate.weekday;
      weekdayTallies[weekday] = (weekdayTallies[weekday] ?? 0) + 1;
    }

    // Find day of week with maximum completed tasks
    int bestWeekday = DateTime.sunday;
    int maxCount = -1;

    // Order of inspection: Sunday (7), Monday (1), ..., Saturday (6)
    final checkOrder = [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];

    for (final wd in checkOrder) {
      final count = weekdayTallies[wd] ?? 0;
      if (count > maxCount) {
        maxCount = count;
        bestWeekday = wd;
      }
    }

    return MostProductiveDayResult(
      dayOfWeek: bestWeekday,
      dayNameKey: getDayTranslationKey(bestWeekday),
      completedTasksCount: maxCount > 0 ? maxCount : 0,
      hasCompletedTasks: maxCount > 0,
    );
  }

  /// Computes full Life Analytics summary.
  static LifeAnalyticsSummary computeSummary({
    required List<CheckinModel> checkins,
    required List<TaskModel> tasks,
  }) {
    final hasCheckins = checkins.isNotEmpty;
    final energyImpact = computeEnergyProductivityImpact(
      checkins: checkins,
      tasks: tasks,
    );
    final mostProductiveDay = computeMostProductiveDay(tasks);

    return LifeAnalyticsSummary(
      hasCheckins: hasCheckins,
      totalCheckins: checkins.length,
      energyImpact: energyImpact,
      mostProductiveDay: mostProductiveDay,
    );
  }
}
