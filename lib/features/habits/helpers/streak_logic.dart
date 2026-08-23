import '../models/habit_model.dart';

/// Pure functions for Habit Streak calculation, Weekly Rollover/Reset,
/// and Milestone Celebrations in Focusly.
///
/// Contains NO side effects or Firestore writes to ensure 100% deterministic testability.
class StreakLogic {
  /// Predefined streak milestone thresholds (in days)
  static const List<int> milestoneThresholds = [3, 7, 14, 30, 60, 100];

  /// Computes the 0..6 index within the week for a given [date]
  /// based on the [weekStartDay] (default: Saturday / DateTime.saturday = 6).
  static int getWeekDayIndex(
    DateTime date, {
    int weekStartDay = DateTime.saturday,
  }) {
    return (date.weekday - weekStartDay + 7) % 7;
  }

  /// Returns the start of the week for a given [date] normalized to midnight.
  static DateTime getStartOfWeek(
    DateTime date, {
    int weekStartDay = DateTime.saturday,
  }) {
    final dayIndex = getWeekDayIndex(date, weekStartDay: weekStartDay);
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: dayIndex));
  }

  /// Returns localized short 2-3 letter labels for all 7 days of the week
  /// in the order starting from [weekStartDay].
  static List<String> getWeekDayLabels({
    bool isArabic = false,
    int weekStartDay = DateTime.saturday,
  }) {
    if (isArabic) {
      if (weekStartDay == DateTime.saturday) {
        return const ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع'];
      } else {
        return const ['أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
      }
    } else {
      if (weekStartDay == DateTime.saturday) {
        return const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
      } else {
        return const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      }
    }
  }

  /// Evaluates whether the habit has crossed into a new week and rolls over
  /// streak and days accordingly.
  ///
  /// Pure function: returns updated [HabitModel].
  static HabitModel evaluateWeeklyReset(
    HabitModel habit,
    DateTime now, {
    int? weekStartDay,
  }) {
    final startDay = weekStartDay ?? habit.resetDay;
    final currentWeekStart = getStartOfWeek(now, weekStartDay: startDay);
    final lastResetWeekStart = habit.lastResetDate != null
        ? getStartOfWeek(habit.lastResetDate!, weekStartDay: startDay)
        : currentWeekStart;

    // Check if we are still in the same week
    if (!currentWeekStart.isAfter(lastResetWeekStart)) {
      return habit;
    }

    // Number of elapsed weeks
    final weeksPassed = currentWeekStart.difference(lastResetWeekStart).inDays ~/ 7;

    int newBaseStreak = habit.baseStreak;
    int newStreak = habit.streak;

    if (weeksPassed == 1) {
      // Exactly 1 week passed: check if the previous week was completely fulfilled
      final completedDays = habit.days.where((d) => d).length;
      final allDaysCompleted = completedDays == 7;

      if (allDaysCompleted) {
        // Perfect streak continued across the boundary
        newBaseStreak += 7;
        newStreak = newBaseStreak;
      } else {
        // A single missed day in the finished week breaks the streak
        newBaseStreak = 0;
        newStreak = 0;
      }
    } else if (weeksPassed > 1) {
      // Multiple weeks passed without logging: full streak reset
      newBaseStreak = 0;
      newStreak = 0;
    }

    return habit.copyWith(
      days: List<bool>.filled(7, false),
      baseStreak: newBaseStreak,
      streak: newStreak,
      lastResetDate: now,
    );
  }

  /// Toggles a day's completion state (0..6) and recalculates the current streak.
  ///
  /// Pure function: returns updated [HabitModel].
  static HabitModel toggleHabitDay(
    HabitModel habit,
    int dayIndex, {
    DateTime? now,
    int? weekStartDay,
  }) {
    if (dayIndex < 0 || dayIndex >= 7) return habit;

    final updatedDays = List<bool>.from(habit.days);
    updatedDays[dayIndex] = !updatedDays[dayIndex];

    // Compute active consecutive days in this week
    final completedCount = updatedDays.where((d) => d).length;

    // Total streak = baseStreak carried over + completed count in current week
    final int newStreak = habit.baseStreak + completedCount;

    return habit.copyWith(
      days: updatedDays,
      streak: newStreak,
    );
  }

  /// Checks if a streak transition crossed a milestone threshold (3, 7, 14, 30, 60, 100 days).
  /// Returns the milestone integer reached, or `null` if no milestone was crossed.
  static int? checkMilestoneCelebration(int oldStreak, int newStreak) {
    if (newStreak <= oldStreak) return null;

    for (final milestone in milestoneThresholds) {
      if (oldStreak < milestone && newStreak >= milestone) {
        return milestone;
      }
    }
    return null;
  }
}
