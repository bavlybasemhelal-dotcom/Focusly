import 'package:cloud_firestore/cloud_firestore.dart';
import '../../tasks/models/task_model.dart';

/// Pure helper estimating time spent on a completed Task based on its priority heuristic.
///
/// - High priority = 2.0 hours
/// - Medium priority = 1.0 hour
/// - Low priority = 0.5 hours
double estimateTaskHours(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.high:
      return 2.0;
    case TaskPriority.medium:
      return 1.0;
    case TaskPriority.low:
      return 0.5;
  }
}

/// Pure helper checking if a given [date] falls within the requested [period] ('week' | 'month' | 'all').
bool isDateInPeriod(DateTime date, String period, [DateTime? now]) {
  if (period == 'all') return true;

  final current = now ?? DateTime.now();
  final dateStart = DateTime(date.year, date.month, date.day);

  if (period == 'week') {
    // Current week starting Monday
    final currentDayStart = DateTime(current.year, current.month, current.day);
    final weekday = currentDayStart.weekday; // 1 = Mon, 7 = Sun
    final mondayStart = currentDayStart.subtract(Duration(days: weekday - 1));
    return !dateStart.isBefore(mondayStart) && !dateStart.isAfter(currentDayStart.add(const Duration(days: 1)));
  }

  if (period == 'month') {
    return date.year == current.year && date.month == current.month;
  }

  return true;
}

/// Pure helper computing combined hours per category (manual logs + completed tasks heuristic)
/// for the specified time [period].
Map<String, double> computeCombinedCategoryHours({
  required List<TimeAuditLogModel> logs,
  required List<TaskModel> completedTasks,
  required String period,
  DateTime? now,
}) {
  final Map<String, double> categoryHours = {};

  // 1. Sum manual logs within period
  for (final log in logs) {
    if (isDateInPeriod(log.date, period, now)) {
      final cat = log.category.toLowerCase().trim();
      categoryHours[cat] = (categoryHours[cat] ?? 0.0) + log.hours;
    }
  }

  // 2. Sum task-derived estimates for completed tasks within period
  for (final task in completedTasks) {
    if (task.done) {
      if (isDateInPeriod(task.date, period, now)) {
        final cat = task.categoryId.toLowerCase().trim();
        final hours = estimateTaskHours(task.priority);
        categoryHours[cat] = (categoryHours[cat] ?? 0.0) + hours;
      }
    }
  }

  // Round all totals to 1 decimal place
  final Map<String, double> rounded = {};
  categoryHours.forEach((cat, hours) {
    if (hours > 0) {
      rounded[cat] = (hours * 10).round() / 10.0;
    }
  });

  return rounded;
}

/// Model representing a manual time-audit log entry.
///
/// Stored in Firestore under: `users/{userId}/timeAuditLogs/{logId}`
class TimeAuditLogModel {
  final String id;
  final String category; // Task category ID e.g. 'work', 'study', 'health', 'personal'
  final double hours; // Number of hours logged (> 0)
  final String description; // Short description
  final DateTime date; // Date of the activity
  final DateTime createdAt;

  const TimeAuditLogModel({
    required this.id,
    required this.category,
    required this.hours,
    this.description = '',
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'hours': hours,
      'description': description,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory TimeAuditLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    final rawHours = (map['hours'] as num?)?.toDouble() ?? 1.0;

    return TimeAuditLogModel(
      id: docId,
      category: map['category'] ?? 'work',
      hours: rawHours > 0 ? rawHours : 1.0,
      description: map['description'] ?? '',
      date: parsedDate,
      createdAt: parsedCreatedAt,
    );
  }

  TimeAuditLogModel copyWith({
    String? id,
    String? category,
    double? hours,
    String? description,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return TimeAuditLogModel(
      id: id ?? this.id,
      category: category ?? this.category,
      hours: hours ?? this.hours,
      description: description ?? this.description,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeAuditLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          hours == other.hours &&
          date == other.date;

  @override
  int get hashCode =>
      id.hashCode ^ category.hashCode ^ hours.hashCode ^ date.hashCode;
}
