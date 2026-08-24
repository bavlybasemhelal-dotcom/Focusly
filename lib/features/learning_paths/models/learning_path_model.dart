import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Single sub-step item inside a learning day's checklist.
class PathSubStepModel {
  final String id;
  final String title;
  final bool completed;

  const PathSubStepModel({
    required this.id,
    required this.title,
    this.completed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
    };
  }

  factory PathSubStepModel.fromMap(Map<String, dynamic> map) {
    return PathSubStepModel(
      id: map['id'] ?? UniqueKey().toString(),
      title: (map['title'] as String?)?.trim() ?? '',
      completed: map['completed'] ?? false,
    );
  }

  PathSubStepModel copyWith({
    String? id,
    String? title,
    bool? completed,
  }) {
    return PathSubStepModel(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathSubStepModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          completed == other.completed;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ completed.hashCode;
}

/// A single day's step in a learning path.
class PathStepModel {
  final int day; // 1..totalDays
  final String title;
  final bool completed;
  final List<PathSubStepModel> subSteps;

  const PathStepModel({
    required this.day,
    this.title = '',
    this.completed = false,
    this.subSteps = const [],
  });

  /// Completed sub-steps count.
  int get completedSubStepsCount => subSteps.where((s) => s.completed).length;

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'title': title,
      'completed': completed,
      'subSteps': subSteps.map((s) => s.toMap()).toList(),
    };
  }

  factory PathStepModel.fromMap(Map<String, dynamic> map) {
    List<PathSubStepModel> subs = [];
    if (map['subSteps'] is List) {
      subs = (map['subSteps'] as List)
          .map((item) => PathSubStepModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return PathStepModel(
      day: (map['day'] as num?)?.toInt() ?? 1,
      title: (map['title'] as String?)?.trim() ?? '',
      completed: map['completed'] ?? false,
      subSteps: subs,
    );
  }

  PathStepModel copyWith({
    int? day,
    String? title,
    bool? completed,
    List<PathSubStepModel>? subSteps,
  }) {
    return PathStepModel(
      day: day ?? this.day,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      subSteps: subSteps ?? this.subSteps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PathStepModel &&
          runtimeType == other.runtimeType &&
          day == other.day &&
          title == other.title &&
          completed == other.completed &&
          listEquals(subSteps, other.subSteps);

  @override
  int get hashCode =>
      day.hashCode ^
      title.hashCode ^
      completed.hashCode ^
      subSteps.fold(0, (prev, elem) => prev ^ elem.hashCode);
}

/// Data model representing an N-Day Learning Path.
///
/// Firestore path: `users/{userId}/learningPaths/{pathId}` (isolated per-user).
class LearningPathModel {
  final String id;
  final String title;
  final int totalDays;
  final List<PathStepModel> steps;
  final int progressDay; // Number of completed days
  final DateTime createdAt;
  final DateTime updatedAt;

  const LearningPathModel({
    required this.id,
    required this.title,
    this.totalDays = 30,
    this.steps = const [],
    this.progressDay = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculates percentage of path completion (0..100).
  int get progressPercent {
    if (totalDays <= 0) return 0;
    final pct = (progressDay / totalDays * 100).round();
    return pct.clamp(0, 100);
  }

  /// Whether all days of the path have been completed.
  bool get isFullyCompleted => totalDays > 0 && progressDay >= totalDays;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'totalDays': totalDays,
      'steps': steps.map((s) => s.toMap()).toList(),
      'progressDay': progressDay,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory LearningPathModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawDays = (map['totalDays'] as num?)?.toInt() ?? 30;
    final total = rawDays > 0 ? rawDays : 30;

    List<PathStepModel> parsedSteps = [];
    if (map['steps'] is List) {
      parsedSteps = (map['steps'] as List)
          .map((item) => PathStepModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    // Sort steps ascending by day
    parsedSteps.sort((a, b) => a.day.compareTo(b.day));

    final rawProgress = (map['progressDay'] as num?)?.toInt() ??
        parsedSteps.where((s) => s.completed).length;

    return LearningPathModel(
      id: docId,
      title: (map['title'] as String?)?.trim() ?? '',
      totalDays: total,
      steps: parsedSteps,
      progressDay: rawProgress.clamp(0, total),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  LearningPathModel copyWith({
    String? id,
    String? title,
    int? totalDays,
    List<PathStepModel>? steps,
    int? progressDay,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LearningPathModel(
      id: id ?? this.id,
      title: title ?? this.title,
      totalDays: totalDays ?? this.totalDays,
      steps: steps ?? this.steps,
      progressDay: progressDay ?? this.progressDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningPathModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          totalDays == other.totalDays &&
          progressDay == other.progressDay &&
          listEquals(steps, other.steps);

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      totalDays.hashCode ^
      progressDay.hashCode ^
      steps.fold(0, (prev, elem) => prev ^ elem.hashCode);
}
