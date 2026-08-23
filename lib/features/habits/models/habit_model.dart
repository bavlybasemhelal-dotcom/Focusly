import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents a single Daily Habit in Focusly.
///
/// Tracks weekly 7-day completion, habit-stacking triggers,
/// current/base consecutive streaks, and weekly reset rules.
class HabitModel {
  final String id;
  final String title;
  final TimeOfDay? time;
  final List<bool> days; // 7 booleans: index 0..6 representing week days
  final int streak; // Current consecutive day streak
  final int baseStreak; // Streak carried over from before the current week
  final String? stackTrigger; // e.g. "Right after brushing my teeth"
  final int resetDay; // Weekday cycle reset day (default: 6 for Saturday / matching week start)
  final bool autoReset; // Whether completed days auto-roll into streak calculation
  final DateTime? lastResetDate; // Last time the weekly cycle was reset
  final DateTime createdAt;

  const HabitModel({
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
  });

  /// Factory constructor to initialize a new habit with 7 uncompleted days
  factory HabitModel.create({
    required String id,
    required String title,
    TimeOfDay? time,
    String? stackTrigger,
    int resetDay = DateTime.saturday,
    bool autoReset = true,
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
    final data = doc.data() as Map<String, dynamic>? ?? {};

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
      parsedCreated = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    }

    return HabitModel(
      id: doc.id,
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
    );
  }

  /// Serializes the HabitModel for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'timeHour': time?.hour,
      'timeMinute': time?.minute,
      'days': days,
      'streak': streak,
      'baseStreak': baseStreak,
      'stackTrigger': stackTrigger,
      'resetDay': resetDay,
      'autoReset': autoReset,
      'lastResetDate': lastResetDate != null ? Timestamp.fromDate(lastResetDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Creates a copy with optionally updated fields
  HabitModel copyWith({
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
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      time: clearTime ? null : (time ?? this.time),
      days: days != null ? List<bool>.from(days) : List<bool>.from(this.days),
      streak: streak ?? this.streak,
      baseStreak: baseStreak ?? this.baseStreak,
      stackTrigger: clearStackTrigger ? null : (stackTrigger ?? this.stackTrigger),
      resetDay: resetDay ?? this.resetDay,
      autoReset: autoReset ?? this.autoReset,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
