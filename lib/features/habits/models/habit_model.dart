import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents a single Daily Habit in Focusly.
///
/// Tracks weekly 7-day completion, habit-stacking triggers,
/// current/base consecutive streaks, and weekly reset rules.
class HabitModel {
  final List<int> weekdays;
  final DateTime? deadline;
  final String id;
  final String title;
  final TimeOfDay? time;
  final List<bool> days; // 7 booleans: index 0..6 representing week days
  final int streak; // Current consecutive day streak
  final int baseStreak; // Streak carried over from before the current week
  final String? stackTrigger; // e.g. "Right after brushing my teeth"
  final int
  resetDay; // Weekday cycle reset day (default: 6 for Saturday / matching week start)
  final bool
  autoReset; // Whether completed days auto-roll into streak calculation
  final DateTime? lastResetDate; // Last time the weekly cycle was reset
  final DateTime createdAt;

  // Group Assignment Specific Fields
  final String?
  groupAssignmentId; // Linked Group Assignment ID (null for personal habits)
  final String? assignedByGroupId; // Group ID that assigned this habit
  final String? assignedByName; // Admin name who created and assigned the habit
  final bool
  locked; // True for group-assigned habits (locks title from member editing)
  final String? completionMode; // 'simple' | 'count'
  final int?
  targetCount; // Target log count when completionMode is 'count' (e.g. 10 times total)
  final int currentCount; // Current logged count towards targetCount
  final bool
  isCompleted; // True if target count is reached or marked fully completed

  const HabitModel({
    this.deadline,
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    required this.id,
    required this.title,
    this.time,
    required this.days,
    this.streak = 0,
    this.baseStreak = 0,
    this.stackTrigger,
    this.resetDay = DateTime.saturday,
    this.autoReset = true,
    this.lastResetDate,
    required this.createdAt,
    this.groupAssignmentId,
    this.assignedByGroupId,
    this.assignedByName,
    this.locked = false,
    this.completionMode = 'simple',
    this.targetCount,
    this.currentCount = 0,
    this.isCompleted = false,
  });

  /// True if this habit originated from a group assignment
  bool get isGroupAssigned =>
      groupAssignmentId != null && groupAssignmentId!.isNotEmpty;

  /// True if this is a group-assigned habit tracking towards a target count
  bool get isCountMode =>
      completionMode == 'count' && targetCount != null && targetCount! > 0;

  /// Factory constructor to initialize a new habit with 7 uncompleted days
  factory HabitModel.create({
    required String id,
    required String title,
    TimeOfDay? time,
    String? stackTrigger,
    int resetDay = DateTime.saturday,
    bool autoReset = true,
    String? groupAssignmentId,
    String? assignedByGroupId,
    String? assignedByName,
    bool locked = false,
    String? completionMode = 'simple',
    int? targetCount,
    int currentCount = 0,
    bool isCompleted = false,
  }) {
    return HabitModel(
      id: id,
      title: title,
      time: time,
      days: List<bool>.filled(7, false),
      streak: 0,
      baseStreak: 0,
      stackTrigger: stackTrigger,
      resetDay: resetDay,
      autoReset: autoReset,
      lastResetDate: DateTime.now(),
      createdAt: DateTime.now(),
      groupAssignmentId: groupAssignmentId,
      assignedByGroupId: assignedByGroupId,
      assignedByName: assignedByName,
      locked: locked,
      completionMode: completionMode,
      targetCount: targetCount,
      currentCount: currentCount,
      isCompleted: isCompleted,
    );
  }

  /// Number of days completed in the current week (0 to 7)
  int get completedThisWeekCount => days.where((d) => d).length;

  /// Returns whether a particular day index (0..6) is completed
  bool isDayCompleted(int index) {
    if (index < 0 || index >= days.length) return false;
    return days[index];
  }

  /// Deserializes a Firestore Document snapshot into a HabitModel
  factory HabitModel.fromFirestore(DocumentSnapshot doc) {
    return HabitModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory HabitModel.fromMap(Map<String, dynamic> data, String id) {
    TimeOfDay? parsedTime;
    if (data['timeHour'] != null && data['timeMinute'] != null) {
      parsedTime = TimeOfDay(
        hour: data['timeHour'] as int,
        minute: data['timeMinute'] as int,
      );
    }

    List<bool> parsedDays = List<bool>.filled(7, false);
    if (data['days'] is List) {
      final list = data['days'] as List;
      parsedDays = List<bool>.generate(7, (i) {
        if (i < list.length && list[i] is bool) {
          return list[i] as bool;
        }
        return false;
      });
    }

    DateTime? parsedLastReset;
    if (data['lastResetDate'] is Timestamp) {
      parsedLastReset = (data['lastResetDate'] as Timestamp).toDate();
    } else if (data['lastResetDate'] is String) {
      parsedLastReset = DateTime.tryParse(data['lastResetDate'] as String);
    }

    DateTime parsedCreated = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedCreated = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedCreated =
          DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    }

    return HabitModel(
      weekdays:
          (data['weekdays'] as List?)
              ?.whereType<int>()
              .where((day) => day >= 1 && day <= 7)
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      deadline: data['deadline'] is Timestamp
          ? (data['deadline'] as Timestamp).toDate()
          : null,
      id: id,
      title: data['title'] as String? ?? '',
      time: parsedTime,
      days: parsedDays,
      streak: data['streak'] as int? ?? 0,
      baseStreak: data['baseStreak'] as int? ?? 0,
      stackTrigger: data['stackTrigger'] as String?,
      resetDay: data['resetDay'] as int? ?? DateTime.saturday,
      autoReset: data['autoReset'] as bool? ?? true,
      lastResetDate: parsedLastReset,
      createdAt: parsedCreated,
      groupAssignmentId: data['groupAssignmentId'] as String?,
      assignedByGroupId: data['assignedByGroupId'] as String?,
      assignedByName: data['assignedByName'] as String?,
      locked: data['locked'] as bool? ?? false,
      completionMode: data['completionMode'] as String? ?? 'simple',
      targetCount: (data['targetCount'] as num?)?.toInt(),
      currentCount: (data['currentCount'] as num?)?.toInt() ?? 0,
      isCompleted: data['isCompleted'] as bool? ?? false,
    );
  }

  /// Serializes the HabitModel for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      'weekdays': weekdays,
      'title': title,
      'timeHour': time?.hour,
      'timeMinute': time?.minute,
      'days': days,
      'streak': streak,
      'baseStreak': baseStreak,
      'stackTrigger': stackTrigger,
      'resetDay': resetDay,
      'autoReset': autoReset,
      'lastResetDate': lastResetDate != null
          ? Timestamp.fromDate(lastResetDate!)
          : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'groupAssignmentId': groupAssignmentId,
      'assignedByGroupId': assignedByGroupId,
      'assignedByName': assignedByName,
      'locked': locked,
      'completionMode': completionMode,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'isCompleted': isCompleted,
    };
  }

  /// Creates a copy with optionally updated fields
  HabitModel copyWith({
    List<int>? weekdays,
    String? id,
    String? title,
    TimeOfDay? time,
    bool clearTime = false,
    List<bool>? days,
    int? streak,
    int? baseStreak,
    String? stackTrigger,
    bool clearStackTrigger = false,
    int? resetDay,
    bool? autoReset,
    DateTime? lastResetDate,
    DateTime? createdAt,
    String? groupAssignmentId,
    String? assignedByGroupId,
    String? assignedByName,
    bool? locked,
    String? completionMode,
    int? targetCount,
    int? currentCount,
    bool? isCompleted,
    bool clearGroupAssignmentId = false,
  }) {
    return HabitModel(
      deadline: deadline,
      weekdays: weekdays ?? this.weekdays,
      id: id ?? this.id,
      title: title ?? this.title,
      time: clearTime ? null : (time ?? this.time),
      days: days != null ? List<bool>.from(days) : List<bool>.from(this.days),
      streak: streak ?? this.streak,
      baseStreak: baseStreak ?? this.baseStreak,
      stackTrigger: clearStackTrigger
          ? null
          : (stackTrigger ?? this.stackTrigger),
      resetDay: resetDay ?? this.resetDay,
      autoReset: autoReset ?? this.autoReset,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      createdAt: createdAt ?? this.createdAt,
      groupAssignmentId: clearGroupAssignmentId
          ? null
          : (groupAssignmentId ?? this.groupAssignmentId),
      assignedByGroupId: assignedByGroupId ?? this.assignedByGroupId,
      assignedByName: assignedByName ?? this.assignedByName,
      locked: locked ?? this.locked,
      completionMode: completionMode ?? this.completionMode,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
