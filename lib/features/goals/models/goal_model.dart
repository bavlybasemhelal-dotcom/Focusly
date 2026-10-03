import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure helper function to calculate overall goal progress percentage (0-100).
///
/// If milestones exist, they act as the single source of truth for progress.
/// If no milestones exist, the user's manual slider progress is preserved.
int calculateMilestoneProgress(
  List<GoalMilestone> milestones, [
  int manualProgress = 0,
]) {
  if (milestones.isEmpty) {
    return manualProgress.clamp(0, 100);
  }
  final completed = milestones.where((m) => m.done).length;
  final pct = ((completed / milestones.length) * 100).round();
  return pct.clamp(0, 100);
}

/// Pure helper returning calendar days remaining until target date (positive = remaining, 0 = today, negative = overdue).
int daysUntilDate(DateTime targetDate, [DateTime? now]) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
  return target.difference(today).inDays;
}

/// Sub-item milestone inside a Goal.
class GoalMilestone {
  final String title;
  final bool done;
  final DateTime? date;

  const GoalMilestone({required this.title, this.done = false, this.date});

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'done': done,
      'date': date != null ? Timestamp.fromDate(date!) : null,
    };
  }

  factory GoalMilestone.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']);
    }

    return GoalMilestone(
      title: map['title'] ?? '',
      done: map['done'] == true,
      date: parsedDate,
    );
  }

  GoalMilestone copyWith({
    String? title,
    bool? done,
    DateTime? date,
    bool clearDate = false,
  }) {
    return GoalMilestone(
      title: title ?? this.title,
      done: done ?? this.done,
      date: clearDate ? null : (date ?? this.date),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalMilestone &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          done == other.done &&
          date == other.date;

  @override
  int get hashCode => title.hashCode ^ done.hashCode ^ date.hashCode;
}

/// Goal entity within the Life Map feature.
///
/// Stored in Firestore under: `users/{userId}/goals/{goalId}`
class GoalModel {
  final String id;
  final String title;
  final String icon; // Emoji, default 🎯
  final String color; // Hex string e.g. '#2563EB'
  final String timeframe; // '1month' | '3months' | '1year' | '5years'
  final String? areaId; // Optional link to a PARA Area
  final DateTime? targetDate;
  final int progress; // 0 - 100
  final String status; // 'active' | 'done'
  final List<GoalMilestone> milestones;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GoalModel({
    required this.id,
    required this.title,
    this.icon = '🎯',
    this.color = '#2563EB',
    this.timeframe = '1month',
    this.areaId,
    this.targetDate,
    this.progress = 0,
    this.status = 'active',
    this.milestones = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDone => status == 'done';
  bool get isActive => status == 'active';

  /// Effective progress percentage based on milestones if present
  int get effectiveProgress => calculateMilestoneProgress(milestones, progress);

  /// Number of completed milestones
  int get completedMilestonesCount => milestones.where((m) => m.done).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'color': color,
      'timeframe': timeframe,
      'areaId': areaId,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'progress': effectiveProgress,
      'status': status,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedTargetDate;
    if (map['targetDate'] is Timestamp) {
      parsedTargetDate = (map['targetDate'] as Timestamp).toDate();
    } else if (map['targetDate'] is String) {
      parsedTargetDate = DateTime.tryParse(map['targetDate']);
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime parsedUpdatedAt;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt = DateTime.tryParse(map['updatedAt']) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    List<GoalMilestone> parsedMilestones = [];
    if (map['milestones'] is List) {
      parsedMilestones = (map['milestones'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => GoalMilestone.fromMap(m))
          .toList();
    }

    final rawProgress = (map['progress'] as num?)?.toInt() ?? 0;

    return GoalModel(
      id: docId,
      title: map['title'] ?? '',
      icon: map['icon'] ?? '🎯',
      color: map['color'] ?? '#2563EB',
      timeframe: map['timeframe'] ?? '1month',
      areaId: map['areaId'],
      targetDate: parsedTargetDate,
      progress: calculateMilestoneProgress(parsedMilestones, rawProgress),
      status: map['status'] ?? 'active',
      milestones: parsedMilestones,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  GoalModel copyWith({
    String? id,
    String? title,
    String? icon,
    String? color,
    String? timeframe,
    String? areaId,
    DateTime? targetDate,
    int? progress,
    String? status,
    List<GoalMilestone>? milestones,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAreaId = false,
    bool clearTargetDate = false,
  }) {
    final newMilestones = milestones ?? this.milestones;
    final newProgress = calculateMilestoneProgress(
      newMilestones,
      progress ?? this.progress,
    );

    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      timeframe: timeframe ?? this.timeframe,
      areaId: clearAreaId ? null : (areaId ?? this.areaId),
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      progress: newProgress,
      status: status ?? this.status,
      milestones: newMilestones,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          icon == other.icon &&
          color == other.color &&
          timeframe == other.timeframe &&
          status == other.status &&
          progress == other.progress;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      icon.hashCode ^
      color.hashCode ^
      timeframe.hashCode ^
      status.hashCode ^
      progress.hashCode;
}
