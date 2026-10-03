import '../../../core/data/calendar_clock.dart';
import '../../energy_mood/models/checkin_model.dart';
import '../../goals/models/goal_model.dart';
import '../../habits/models/habit_model.dart';
import '../../reading_tracker/models/book_model.dart';
import '../../tasks/models/task_model.dart';
import '../models/life_score_model.dart';

/// Pure calculation helper isolating the Weekly Life Score mathematics.
///
/// Combines 6 distinct productivity and wellness dimensions with precise weightings:
/// - Tasks: 30%
/// - Habits: 25% (live for current week, stored snapshot for past weeks)
/// - Energy: 15%
/// - Learning (Reading): 10%
/// - Daily Check-ins: 10%
/// - Goals Progress: 10%
class LifeScoreCalculator {
  /// Returns the Sunday 00:00:00 start of the week for any given date.
  static DateTime getWeekStart(DateTime date) {
    final startOfDate = DateTime(date.year, date.month, date.day);
    final weekdayOffset =
        (date.weekday - DateTime.saturday + 7) % 7; // Sunday is 0
    return calendarDay(startOfDate, -weekdayOffset);
  }

  /// Returns the Saturday 23:59:59 end of the week for any given weekStart.
  static DateTime getWeekEnd(DateTime weekStart) {
    return DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
      23,
      59,
      59,
      999,
    ).add(const Duration(days: 6));
  }

  /// Normalizes date to "YYYY-MM-DD" string.
  static String formatWeekId(DateTime date) {
    final ws = getWeekStart(date);
    final y = ws.year.toString().padLeft(4, '0');
    final m = ws.month.toString().padLeft(2, '0');
    final d = ws.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Checks if a date falls within [weekStart, weekEnd] inclusive.
  static bool isDateInWeek(
    DateTime target,
    DateTime weekStart,
    DateTime weekEnd,
  ) {
    return (target.isAfter(weekStart) || target.isAtSameMomentAs(weekStart)) &&
        (target.isBefore(weekEnd) || target.isAtSameMomentAs(weekEnd));
  }

  /// Computes the complete Weekly Life Score.
  ///
  /// [weekStart] is the start date of the week being evaluated.
  /// [isCurrentWeek] indicates if this calculation is for the active current week.
  /// [pastWeekSnapshot] provides the preserved historical habits score for past weeks.
  static LifeScoreModel computeLifeScore({
    required DateTime weekStart,
    required List<TaskModel> tasks,
    required List<HabitModel> habits,
    required List<CheckinModel> checkins,
    required List<BookModel> books,
    required List<GoalModel> goals,
    LifeScoreModel? pastWeekSnapshot,
    bool isCurrentWeek = true,
  }) {
    final weekEnd = getWeekEnd(weekStart);
    final weekOfStr = formatWeekId(weekStart);

    // =========================================================================
    // 1. TASKS (30% Weight)
    // =========================================================================
    // Formula: (tasks completed within the week ÷ tasks created/dated within the week) * 100
    // Capped at 100. If 0 created/dated: 100 if any completed, otherwise 0.
    final tasksCreatedOrDatedInWeek = tasks.where((t) {
      final isDateIn = isDateInWeek(t.date, weekStart, weekEnd);
      final isCreatedIn = isDateInWeek(t.createdAt, weekStart, weekEnd);
      return isDateIn || isCreatedIn;
    }).toList();

    final tasksCompletedInWeek = tasks.where((t) {
      if (!t.done) return false;
      if (t.doneAt == null) return false;
      final completionDate = t.doneAt!;
      return isDateInWeek(completionDate, weekStart, weekEnd);
    }).toList();

    final denominator = {
      ...tasksCreatedOrDatedInWeek.map((task) => task.id),
      ...tasksCompletedInWeek.map((task) => task.id),
    }.length;
    double tasksScore = 0.0;
    if (tasksCreatedOrDatedInWeek.isNotEmpty) {
      tasksScore = (tasksCompletedInWeek.length / denominator) * 100.0;
    } else if (tasksCompletedInWeek.isNotEmpty) {
      tasksScore =
          100.0; // Edge case: completed tasks exist with 0 created in week
    } else {
      tasksScore = 0.0;
    }
    tasksScore = tasksScore.clamp(0.0, 100.0);

    // =========================================================================
    // 2. HABITS (25% Weight)
    // =========================================================================
    // For CURRENT week: (sum of all habits' checked days this week ÷ (number of habits * 7)) * 100
    // For PAST weeks: Read stored snapshot habits score (Habits reset clears days array weekly).
    double habitsScore = 0.0;
    if (isCurrentWeek) {
      if (habits.isNotEmpty) {
        int totalCheckedDays = 0;
        for (final habit in habits) {
          totalCheckedDays += habit.completedThisWeekCount;
        }
        habitsScore = (totalCheckedDays / (habits.length * 7.0)) * 100.0;
      } else {
        habitsScore = 0.0;
      }
    } else {
      habitsScore = pastWeekSnapshot?.breakdown.habits ?? 0.0;
    }
    habitsScore = habitsScore.clamp(0.0, 100.0);

    // =========================================================================
    // 3. ENERGY LEVEL (15% Weight)
    // =========================================================================
    // Average energy level (1-5) logged via check-ins that week, scaled to 0-100 (÷5 * 100).
    final weekCheckins = checkins.where((c) {
      final parsedDate = DateTime.tryParse(c.date);
      if (parsedDate == null) return false;
      return c.energy >= 1 &&
          c.energy <= 5 &&
          isDateInWeek(parsedDate, weekStart, weekEnd);
    }).toList();

    double energyScore = 0.0;
    if (weekCheckins.isNotEmpty) {
      final totalEnergy = weekCheckins.fold<int>(0, (sum, c) => sum + c.energy);
      final avgEnergy = totalEnergy / weekCheckins.length;
      energyScore = (avgEnergy / 5.0) * 100.0;
    } else {
      energyScore = 0.0;
    }
    energyScore = energyScore.clamp(0.0, 100.0);

    // =========================================================================
    // 4. LEARNING (READING) (10% Weight)
    // =========================================================================
    // (books finished that week * 25), capped at 100.
    final booksFinishedInWeek = books.where((b) {
      if (!b.isFinished) return false;
      final finishDate = b.finishDate ?? b.updatedAt;
      return isDateInWeek(finishDate, weekStart, weekEnd);
    }).toList();

    double learningScore = (booksFinishedInWeek.length * 25.0).clamp(
      0.0,
      100.0,
    );

    // =========================================================================
    // 5. DAILY CHECK-INS (10% Weight)
    // =========================================================================
    // (number of distinct days that week with a logged Energy & Mood check-in ÷ 7) * 100
    final distinctCheckinDates = weekCheckins.map((c) => c.date).toSet();
    double checkinsScore = ((distinctCheckinDates.length / 7.0) * 100.0).clamp(
      0.0,
      100.0,
    );

    // =========================================================================
    // 6. GOALS PROGRESS (10% Weight)
    // =========================================================================
    // Average progress percentage across all active goals.
    final activeGoals = goals.where((g) => g.isActive).toList();
    double goalsScore = 0.0;
    if (activeGoals.isNotEmpty) {
      final totalProgress = activeGoals.fold<int>(
        0,
        (sum, g) => sum + g.effectiveProgress,
      );
      goalsScore = (totalProgress / activeGoals.length).toDouble();
    } else {
      goalsScore = 0.0;
    }
    goalsScore = goalsScore.clamp(0.0, 100.0);

    // =========================================================================
    // TOTAL WEIGHTED SUM (0 - 100)
    // =========================================================================
    final double rawWeightedTotal =
        (tasksScore * 0.30) +
        (habitsScore * 0.25) +
        (energyScore * 0.15) +
        (learningScore * 0.10) +
        (checkinsScore * 0.10) +
        (goalsScore * 0.10);

    final int total = rawWeightedTotal.round().clamp(0, 100);

    final breakdown = ScoreBreakdown(
      tasks: (tasksScore * 10).round() / 10.0,
      habits: (habitsScore * 10).round() / 10.0,
      energy: (energyScore * 10).round() / 10.0,
      learning: (learningScore * 10).round() / 10.0,
      checkins: (checkinsScore * 10).round() / 10.0,
      goals: (goalsScore * 10).round() / 10.0,
    );

    return LifeScoreModel(
      id: weekOfStr,
      weekOf: weekOfStr,
      total: total,
      breakdown: breakdown,
      computedAt: DateTime.now(),
    );
  }
}
