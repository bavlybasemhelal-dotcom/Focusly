import 'dart:math';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_log_model.dart';
import 'package:focusly/features/schedule/models/event_model.dart';
import 'package:focusly/features/tasks/models/category_model.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import '../models/report_models.dart';

/// Pure data aggregation and productivity score calculation engine
/// for the Advanced PDF Reports feature.
class ReportDataAggregator {
  /// Computes the start date for the given [rangeOption] relative to [now].
  static DateTime computeStartDate(ReportRangeOption rangeOption, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: rangeOption.daysCount - 1));
  }

  /// Checks if a date falls within [start, end] inclusive (by date components).
  static bool isDateInRange(DateTime date, DateTime start, DateTime end) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return (d.isAfter(s) || d.isAtSameMomentAs(s)) &&
        (d.isBefore(e) || d.isAtSameMomentAs(e));
  }

  /// Computes the Productivity Score and Tier Result from raw metrics and days count.
  static ProductivityScoreResult computeProductivityScore({
    required int completedTasks,
    required int totalFocusMinutes,
    required int habitDaysLogged,
    required int daysCount,
  }) {
    // 1. Target values scaled with range length
    final double targetTasks = daysCount == 7 ? 12.0 : (daysCount * 1.5);
    final double targetFocusMinutes = daysCount == 7 ? 300.0 : (daysCount * 40.0);
    final double targetHabitDays = daysCount == 7 ? 14.0 : (daysCount * 2.0);

    // 2. Component scores (0 to 100)
    final int taskScore = targetTasks > 0
        ? min(100, (completedTasks / targetTasks * 100.0).round())
        : 0;

    final int focusScore = targetFocusMinutes > 0
        ? min(100, (totalFocusMinutes / targetFocusMinutes * 100.0).round())
        : 0;

    final int habitsScore = targetHabitDays > 0
        ? min(100, (habitDaysLogged / targetHabitDays * 100.0).round())
        : 0;

    // 3. Weighted overall score (Tasks 40%, Focus 30%, Habits 30%)
    final int overallScore = (taskScore * 0.4 + focusScore * 0.3 + habitsScore * 0.3)
        .round()
        .clamp(0, 100);

    // 4. Rating tier & colors
    final String tierKey;
    final int tierColorHex;

    if (overallScore >= 90) {
      tierKey = 'score_tier_incredible';
      tierColorHex = 0xFF10B981; // Teal / Emerald
    } else if (overallScore >= 75) {
      tierKey = 'score_tier_excellent';
      tierColorHex = 0xFF06B6D4; // Cyan
    } else if (overallScore >= 50) {
      tierKey = 'score_tier_balanced';
      tierColorHex = 0xFFF59E0B; // Amber
    } else if (overallScore >= 25) {
      tierKey = 'score_tier_good_start';
      tierColorHex = 0xFF8B5CF6; // Purple
    } else {
      tierKey = 'score_tier_needs_focus';
      tierColorHex = 0xFFEF4444; // Red
    }

    return ProductivityScoreResult(
      taskScore: taskScore,
      focusScore: focusScore,
      habitsScore: habitsScore,
      overallScore: overallScore,
      tierKey: tierKey,
      tierColorHex: tierColorHex,
    );
  }

  /// Aggregates all activity data across the specified date range.
  static ReportData aggregateReportData({
    required ReportRangeOption rangeOption,
    required List<TaskModel> tasks,
    required List<EventModel> events,
    required List<HabitModel> habits,
    required List<PomodoroLogModel> pomodoroLogs,
    List<TaskCategory> categories = const [],
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final startDate = computeStartDate(rangeOption, now);
    final endDate = DateTime(now.year, now.month, now.day);
    final daysCount = rangeOption.daysCount;

    // =========================================================================
    // 1. TASKS AGGREGATION
    // =========================================================================
    final tasksInRange = tasks.where((t) {
      return isDateInRange(t.date, startDate, endDate) ||
          isDateInRange(t.createdAt, startDate, endDate);
    }).toList();

    final completedTasksInRange = tasks.where((t) {
      if (!t.done) return false;
      final completionDate = t.doneAt ?? t.date;
      return isDateInRange(completionDate, startDate, endDate);
    }).toList();

    final completedTasksCount = completedTasksInRange.length;
    final totalTasksCount = max(tasksInRange.length, completedTasksCount);
    final pendingTasksCount = max(0, totalTasksCount - completedTasksCount);

    final completionRatePercent = totalTasksCount > 0
        ? ((completedTasksCount / totalTasksCount) * 100).round().clamp(0, 100)
        : 0;

    // Category breakdown
    final categoryCounts = <String, int>{};
    for (final task in completedTasksInRange) {
      final catId = task.categoryId.isNotEmpty ? task.categoryId : 'other';
      categoryCounts[catId] = (categoryCounts[catId] ?? 0) + 1;
    }

    final categoryMap = {for (var c in categories) c.id: c};
    final categoryStats = <ReportCategoryStat>[];

    final defaultColors = [
      0xFF6366F1, // Indigo
      0xFF10B981, // Emerald
      0xFFF59E0B, // Amber
      0xFF06B6D4, // Cyan
      0xFFEC4899, // Pink
      0xFF8B5CF6, // Purple
      0xFF64748B, // Slate
    ];
    int colorIdx = 0;

    categoryCounts.forEach((catId, count) {
      final categoryObj = categoryMap[catId];
      final name = categoryObj?.nameKey ?? catId;
      final colorVal = categoryObj != null
          ? categoryObj.colorValue
          : defaultColors[colorIdx % defaultColors.length];
      colorIdx++;

      final pct = completedTasksCount > 0
          ? ((count / completedTasksCount) * 100.0 * 10).round() / 10.0
          : 0.0;

      categoryStats.add(ReportCategoryStat(
        categoryId: catId,
        categoryName: name,
        count: count,
        percentage: pct,
        colorValue: colorVal,
      ));
    });

    // =========================================================================
    // 2. EVENTS AGGREGATION
    // =========================================================================
    final eventsCount = events.where((e) {
      return isDateInRange(e.date, startDate, endDate);
    }).length;

    // =========================================================================
    // 3. HABITS AGGREGATION
    // =========================================================================
    int habitDaysLogged = 0;
    for (final habit in habits) {
      habitDaysLogged += habit.completedThisWeekCount;
    }
    // Scale habit completions when evaluating longer multi-week ranges
    if (daysCount > 7) {
      final weeksFactor = daysCount / 7.0;
      habitDaysLogged = (habitDaysLogged * weeksFactor).round();
    }

    // =========================================================================
    // 4. POMODORO / FOCUS AGGREGATION
    // =========================================================================
    final focusLogsInRange = pomodoroLogs.where((log) {
      return isDateInRange(log.date, startDate, endDate);
    }).toList();

    int totalFocusMinutes = 0;
    int totalDistractions = 0;

    for (final log in focusLogsInRange) {
      totalFocusMinutes += log.durationMinutes;
      totalDistractions += log.distractionCount;
    }

    final double avgDistractionsPerSession = focusLogsInRange.isNotEmpty
        ? ((totalDistractions / focusLogsInRange.length) * 10).round() / 10.0
        : 0.0;

    // =========================================================================
    // 5. DAILY / WEEKLY TREND SERIES
    // =========================================================================
    final trendPoints = <ReportTrendPoint>[];

    if (daysCount <= 30) {
      // Daily granularity
      for (int i = 0; i < daysCount; i++) {
        final day = startDate.add(Duration(days: i));
        final dayTasks = completedTasksInRange.where((t) {
          final cd = t.doneAt ?? t.date;
          return isDateInRange(cd, day, day);
        }).length;

        final dayFocus = focusLogsInRange.where((l) {
          return isDateInRange(l.date, day, day);
        }).fold<int>(0, (sum, l) => sum + l.durationMinutes);

        final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final label = '${months[day.month - 1]} ${day.day}';

        trendPoints.add(ReportTrendPoint(
          label: label,
          date: day,
          tasksCompleted: dayTasks,
          focusMinutes: dayFocus,
        ));
      }
    } else {
      // Weekly granularity (TODO: Granularity can be further customized per range)
      final numWeeks = (daysCount / 7.0).ceil();
      for (int w = 0; w < numWeeks; w++) {
        final weekStart = startDate.add(Duration(days: w * 7));
        final weekEnd = weekStart.add(const Duration(days: 6));

        final weekTasks = completedTasksInRange.where((t) {
          final cd = t.doneAt ?? t.date;
          return isDateInRange(cd, weekStart, weekEnd);
        }).length;

        final weekFocus = focusLogsInRange.where((l) {
          return isDateInRange(l.date, weekStart, weekEnd);
        }).fold<int>(0, (sum, l) => sum + l.durationMinutes);

        trendPoints.add(ReportTrendPoint(
          label: 'W${w + 1}',
          date: weekStart,
          tasksCompleted: weekTasks,
          focusMinutes: weekFocus,
        ));
      }
    }

    // =========================================================================
    // 6. PRODUCTIVITY SCORE EVALUATION
    // =========================================================================
    final score = computeProductivityScore(
      completedTasks: completedTasksCount,
      totalFocusMinutes: totalFocusMinutes,
      habitDaysLogged: habitDaysLogged,
      daysCount: daysCount,
    );

    return ReportData(
      rangeOption: rangeOption,
      startDate: startDate,
      endDate: endDate,
      completedTasksCount: completedTasksCount,
      pendingTasksCount: pendingTasksCount,
      totalTasksCount: totalTasksCount,
      completionRatePercent: completionRatePercent,
      eventsCount: eventsCount,
      habitDaysLogged: habitDaysLogged,
      totalFocusMinutes: totalFocusMinutes,
      avgDistractionsPerSession: avgDistractionsPerSession,
      score: score,
      categoryStats: categoryStats,
      trendPoints: trendPoints,
    );
  }
}
