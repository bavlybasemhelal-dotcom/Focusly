import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Task priority enum with localized title key and color tokens.
enum TaskPriority {
  high(
    titleKey: 'priority_high',
    colorValue: 0xFFEF4444, // Error Red
  ),
  medium(
    titleKey: 'priority_medium',
    colorValue: 0xFFF59E0B, // Amber Gold
  ),
  low(
    titleKey: 'priority_low',
    colorValue: 0xFF10B981, // Emerald Green
  );

  final String titleKey;
  final int colorValue;

  const TaskPriority({
    required this.titleKey,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  static TaskPriority fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return TaskPriority.high;
      case 'low':
        return TaskPriority.low;
      case 'medium':
      default:
        return TaskPriority.medium;
    }
  }
}

/// The 4 Eisenhower Decision Matrix Quadrants.
enum EisenhowerQuadrant {
  q1DoNow(
    titleKey: 'matrix_q1_title',
    subtitleKey: 'matrix_q1_sub',
    emptyKey: 'matrix_q1_empty',
    accentColorValue: 0xFFEF4444, // Vibrant Red
    badgeIcon: Icons.local_fire_department_rounded,
  ),
  q2Schedule(
    titleKey: 'matrix_q2_title',
    subtitleKey: 'matrix_q2_sub',
    emptyKey: 'matrix_q2_empty',
    accentColorValue: 0xFF10B981, // Vibrant Emerald
    badgeIcon: Icons.event_available_rounded,
  ),
  q3Delegate(
    titleKey: 'matrix_q3_title',
    subtitleKey: 'matrix_q3_sub',
    emptyKey: 'matrix_q3_empty',
    accentColorValue: 0xFFF59E0B, // Vibrant Amber
    badgeIcon: Icons.group_work_rounded,
  ),
  q4Eliminate(
    titleKey: 'matrix_q4_title',
    subtitleKey: 'matrix_q4_sub',
    emptyKey: 'matrix_q4_empty',
    accentColorValue: 0xFF64748B, // Slate Muted
    badgeIcon: Icons.delete_sweep_rounded,
  );

  final String titleKey;
  final String subtitleKey;
  final String emptyKey;
  final int accentColorValue;
  final IconData badgeIcon;

  const EisenhowerQuadrant({
    required this.titleKey,
    required this.subtitleKey,
    required this.emptyKey,
    required this.accentColorValue,
    required this.badgeIcon,
  });

  Color get accentColor => Color(accentColorValue);
}

/// Single subtask item model (one-level checklist only).
class SubtaskModel {
  final String id;
  final String title;
  final bool done;

  const SubtaskModel({
    required this.id,
    required this.title,
    this.done = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'done': done,
    };
  }

  factory SubtaskModel.fromMap(Map<String, dynamic> map) {
    return SubtaskModel(
      id: map['id'] ?? UniqueKey().toString(),
      title: map['title'] ?? '',
      done: map['done'] ?? false,
    );
  }

  SubtaskModel copyWith({
    String? id,
    String? title,
    bool? done,
  }) {
    return SubtaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
    );
  }
}

/// Main Task data model stored in Firestore under users/{uid}/tasks/{taskId}.
class TaskModel {
  final String id;
  final String title;
  final String? notes;
  final String categoryId;
  final TaskPriority priority;
  final DateTime date;
  final TimeOfDay? time;
  final DateTime? deadline;
  final bool done;
  final DateTime? doneAt;
  final List<SubtaskModel> subtasks;
  final DateTime createdAt;

  // GTD Specific Optional Fields
  final String? listType; // 'waiting' | 'someday' | 'reference' | null (standard task)
  final String? waitingFor; // Name of person / organization being waited on
  final DateTime? waitingSince; // Date when waiting started

  // PARA Specific Optional Fields
  final String? projectId; // Linked PARA Project ID

  // Skills Board Specific Optional Field
  final String? skillId; // Explicitly linked Skill ID (optional)

  // Group Assignment Specific Fields
  final String? groupAssignmentId; // Linked Group Assignment ID (null for personal tasks)
  final String? assignedByGroupId; // Group ID that assigned this task
  final String? assignedByName; // Admin name who created and assigned the task
  final bool locked; // True for group-assigned tasks (locks title and deadline from member editing)
  final String? completionMode; // 'simple' | 'count'
  final int? targetCount; // Target repetition count when completionMode is 'count'
  final int currentCount; // Current progress count towards targetCount

  const TaskModel({
    required this.id,
    required this.title,
    this.notes,
    required this.categoryId,
    this.priority = TaskPriority.medium,
    required this.date,
    this.time,
    this.deadline,
    this.done = false,
    this.doneAt,
    this.subtasks = const [],
    required this.createdAt,
    this.listType,
    this.waitingFor,
    this.waitingSince,
    this.projectId,
    this.skillId,
    this.groupAssignmentId,
    this.assignedByGroupId,
    this.assignedByName,
    this.locked = false,
    this.completionMode = 'simple',
    this.targetCount,
    this.currentCount = 0,
  });

  /// True if this task originated from a group assignment
  bool get isGroupAssigned => groupAssignmentId != null && groupAssignmentId!.isNotEmpty;

  /// Calculates completed subtasks count
  int get completedSubtasksCount => subtasks.where((s) => s.done).length;

  /// Pure computation function: Computes the Eisenhower Quadrant for a task
  /// without mutating state.
  ///
  /// Rule:
  /// - isUrgent = task's date is today/past OR deadline is within 2 days (<= 48h)
  /// - isImportant = priority is high or medium
  ///
  /// Q1 (Do Now): Urgent AND Important
  /// Q2 (Schedule): Important AND NOT Urgent
  /// Q3 (Delegate): Urgent AND NOT Important
  /// Q4 (Eliminate): Neither Urgent nor Important
  EisenhowerQuadrant get computedQuadrant {
    return computeQuadrant(this);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'categoryId': categoryId,
      'priority': priority.name,
      'date': Timestamp.fromDate(date),
      'time': time != null ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}' : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'done': done,
      'doneAt': doneAt != null ? Timestamp.fromDate(doneAt!) : null,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'listType': listType,
      'waitingFor': waitingFor,
      'waitingSince': waitingSince != null ? Timestamp.fromDate(waitingSince!) : null,
      'projectId': projectId,
      'skillId': skillId,
      'groupAssignmentId': groupAssignmentId,
      'assignedByGroupId': assignedByGroupId,
      'assignedByName': assignedByName,
      'locked': locked,
      'completionMode': completionMode,
      'targetCount': targetCount,
      'currentCount': currentCount,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime? parsedDeadline;
    if (map['deadline'] is Timestamp) {
      parsedDeadline = (map['deadline'] as Timestamp).toDate();
    } else if (map['deadline'] is String) {
      parsedDeadline = DateTime.tryParse(map['deadline']);
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedWaitingSince;
    if (map['waitingSince'] is Timestamp) {
      parsedWaitingSince = (map['waitingSince'] as Timestamp).toDate();
    } else if (map['waitingSince'] is String) {
      parsedWaitingSince = DateTime.tryParse(map['waitingSince']);
    }

    DateTime? parsedDoneAt;
    if (map['doneAt'] is Timestamp) {
      parsedDoneAt = (map['doneAt'] as Timestamp).toDate();
    } else if (map['doneAt'] is String) {
      parsedDoneAt = DateTime.tryParse(map['doneAt']);
    }

    TimeOfDay? parsedTime;
    if (map['time'] is String && (map['time'] as String).contains(':')) {
      final parts = (map['time'] as String).split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          parsedTime = TimeOfDay(hour: hour, minute: minute);
        }
      }
    }

    List<SubtaskModel> subtasksList = [];
    if (map['subtasks'] is List) {
      subtasksList = (map['subtasks'] as List)
          .map((item) => SubtaskModel.fromMap(Map<String, dynamic>.from(item)))
          .toList();
    }

    return TaskModel(
      id: docId,
      title: map['title'] ?? '',
      notes: map['notes'],
      categoryId: map['categoryId'] ?? 'personal',
      priority: TaskPriority.fromString(map['priority']),
      date: parsedDate,
      time: parsedTime,
      deadline: parsedDeadline,
      done: map['done'] ?? false,
      doneAt: parsedDoneAt,
      subtasks: subtasksList,
      createdAt: parsedCreatedAt,
      listType: map['listType'],
      waitingFor: map['waitingFor'],
      waitingSince: parsedWaitingSince,
      projectId: map['projectId'],
      skillId: map['skillId'],
      groupAssignmentId: map['groupAssignmentId'],
      assignedByGroupId: map['assignedByGroupId'],
      assignedByName: map['assignedByName'],
      locked: map['locked'] ?? false,
      completionMode: map['completionMode'] ?? 'simple',
      targetCount: (map['targetCount'] as num?)?.toInt(),
      currentCount: (map['currentCount'] as num?)?.toInt() ?? 0,
    );
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? notes,
    String? categoryId,
    TaskPriority? priority,
    DateTime? date,
    TimeOfDay? time,
    DateTime? deadline,
    bool? done,
    DateTime? doneAt,
    List<SubtaskModel>? subtasks,
    DateTime? createdAt,
    String? listType,
    String? waitingFor,
    DateTime? waitingSince,
    String? projectId,
    String? skillId,
    String? groupAssignmentId,
    String? assignedByGroupId,
    String? assignedByName,
    bool? locked,
    String? completionMode,
    int? targetCount,
    int? currentCount,
    bool clearTime = false,
    bool clearDeadline = false,
    bool clearDoneAt = false,
    bool clearListType = false,
    bool clearWaitingFor = false,
    bool clearWaitingSince = false,
    bool clearProjectId = false,
    bool clearSkillId = false,
    bool clearGroupAssignmentId = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      date: date ?? this.date,
      time: clearTime ? null : (time ?? this.time),
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      done: done ?? this.done,
      doneAt: clearDoneAt ? null : (doneAt ?? this.doneAt),
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      listType: clearListType ? null : (listType ?? this.listType),
      waitingFor: clearWaitingFor ? null : (waitingFor ?? this.waitingFor),
      waitingSince: clearWaitingSince ? null : (waitingSince ?? this.waitingSince),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      skillId: clearSkillId ? null : (skillId ?? this.skillId),
      groupAssignmentId: clearGroupAssignmentId ? null : (groupAssignmentId ?? this.groupAssignmentId),
      assignedByGroupId: assignedByGroupId ?? this.assignedByGroupId,
      assignedByName: assignedByName ?? this.assignedByName,
      locked: locked ?? this.locked,
      completionMode: completionMode ?? this.completionMode,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
    );
  }
}

/// Pure standalone calculation of the Eisenhower Quadrant for a given task.
EisenhowerQuadrant computeQuadrant(TaskModel task) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final taskDateStart = DateTime(task.date.year, task.date.month, task.date.day);

  // Urgent condition: date is today/past OR deadline is within 48 hours
  final bool isDateTodayOrPast = taskDateStart.isBefore(todayStart) ||
      taskDateStart.isAtSameMomentAs(todayStart);

  bool isDeadlineUrgent = false;
  if (task.deadline != null) {
    final difference = task.deadline!.difference(now);
    if (difference.inHours <= 48 && !difference.isNegative) {
      isDeadlineUrgent = true;
    }
  }

  final bool isUrgent = isDateTodayOrPast || isDeadlineUrgent;

  // Important condition: Priority is High or Medium
  final bool isImportant =
      task.priority == TaskPriority.high || task.priority == TaskPriority.medium;

  if (isImportant && isUrgent) {
    return EisenhowerQuadrant.q1DoNow;
  } else if (isImportant && !isUrgent) {
    return EisenhowerQuadrant.q2Schedule;
  } else if (!isImportant && isUrgent) {
    return EisenhowerQuadrant.q3Delegate;
  } else {
    return EisenhowerQuadrant.q4Eliminate;
  }
}

/// Pure rule engine that modifies a task's priority/date when assigned or dropped
/// into a specific quadrant.
TaskModel applyQuadrantRule(TaskModel task, EisenhowerQuadrant quadrant) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final nextWeek = today.add(const Duration(days: 7));

  switch (quadrant) {
    case EisenhowerQuadrant.q1DoNow:
      // Q1: Urgent + Important -> Priority = High, Date = Today
      return task.copyWith(
        priority: TaskPriority.high,
        date: today,
      );

    case EisenhowerQuadrant.q2Schedule:
      // Q2: Not Urgent + Important -> Priority = High, Date = +7 days
      return task.copyWith(
        priority: TaskPriority.high,
        date: nextWeek,
      );

    case EisenhowerQuadrant.q3Delegate:
      // Q3: Urgent + Not Important -> Priority = Low, Date = Today
      return task.copyWith(
        priority: TaskPriority.low,
        date: today,
      );

    case EisenhowerQuadrant.q4Eliminate:
      // Q4: Neither -> Priority = Low, Date = +7 days, Clear deadline
      return task.copyWith(
        priority: TaskPriority.low,
        date: nextWeek,
        clearDeadline: true,
      );
  }
}
