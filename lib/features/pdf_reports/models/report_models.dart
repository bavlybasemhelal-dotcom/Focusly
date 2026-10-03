import 'package:flutter/material.dart';

/// Available date range options for PDF productivity reports.
enum ReportRangeOption {
  weekly(
    daysCount: 7,
    titleKey: 'report_range_weekly',
    icon: Icons.calendar_view_week_rounded,
  ),
  monthly(
    daysCount: 30,
    titleKey: 'report_range_monthly',
    icon: Icons.calendar_month_rounded,
  ),
  semiAnnual(
    daysCount: 180,
    titleKey: 'report_range_semi_annual',
    icon: Icons.date_range_rounded,
  ),
  annual(
    daysCount: 365,
    titleKey: 'report_range_annual',
    icon: Icons.event_note_rounded,
  );

  final int daysCount;
  final String titleKey;
  final IconData icon;

  const ReportRangeOption({
    required this.daysCount,
    required this.titleKey,
    required this.icon,
  });
}

/// Statistics per task category completed within the report range.
class ReportCategoryStat {
  final String categoryId;
  final String categoryName;
  final int count;
  final double percentage; // 0.0 to 100.0
  final int colorValue; // ARGB color integer

  const ReportCategoryStat({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.percentage,
    this.colorValue = 0xFF6366F1,
  });
}

/// A single daily or weekly data point in the productivity trend series.
class ReportTrendPoint {
  final String label; // e.g. "Mon" or "Aug 24" or "W34"
  final DateTime date;
  final int tasksCompleted;
  final int focusMinutes;

  const ReportTrendPoint({
    required this.label,
    required this.date,
    required this.tasksCompleted,
    required this.focusMinutes,
  });
}

/// Evaluated productivity score and tier information.
class ProductivityScoreResult {
  final int taskScore; // 0 to 100
  final int focusScore; // 0 to 100
  final int habitsScore; // 0 to 100
  final int overallScore; // 0 to 100
  final String tierKey;
  final int tierColorHex;

  const ProductivityScoreResult({
    required this.taskScore,
    required this.focusScore,
    required this.habitsScore,
    required this.overallScore,
    required this.tierKey,
    required this.tierColorHex,
  });
}

/// Comprehensive aggregated report data payload used by PDF builder.
class ReportData {
  final ReportRangeOption rangeOption;
  final DateTime startDate;
  final DateTime endDate;
  final int completedTasksCount;
  final int pendingTasksCount;
  final int totalTasksCount;
  final int completionRatePercent;
  final int eventsCount;
  final int habitDaysLogged;
  final int totalFocusMinutes;
  final double avgDistractionsPerSession;
  final ProductivityScoreResult score;
  final List<ReportCategoryStat> categoryStats;
  final List<ReportTrendPoint> trendPoints;

  const ReportData({
    required this.rangeOption,
    required this.startDate,
    required this.endDate,
    required this.completedTasksCount,
    required this.pendingTasksCount,
    required this.totalTasksCount,
    required this.completionRatePercent,
    required this.eventsCount,
    required this.habitDaysLogged,
    required this.totalFocusMinutes,
    required this.avgDistractionsPerSession,
    required this.score,
    required this.categoryStats,
    required this.trendPoints,
  });

  String get formattedFocusTime {
    final hours = totalFocusMinutes ~/ 60;
    final minutes = totalFocusMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
