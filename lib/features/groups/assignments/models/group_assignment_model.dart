import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing an Admin-assigned Task or Habit in a Group.
///
/// Stored in Firestore under: `groups/{groupId}/assignments/{assignmentId}`
///
/// When created by an admin, corresponding locked Task or Habit items are
/// automatically dispatched to each assigned member's personal collection.
class GroupAssignmentModel {
  final String id;
  final String groupId;
  final String type; // 'task' | 'habit'
  final String title; // Required, locked once created
  final DateTime?
  deadline; // Due date for type='task'; start date for type='habit'
  final String completionMode; // 'simple' | 'count'
  final int? targetCount; // Required when completionMode='count'
  final List<String> assignedTo; // Array of member UIDs
  final String createdBy; // Admin UID
  final String createdByName; // Admin name snapshot at creation
  final DateTime createdAt;

  const GroupAssignmentModel({
    required this.id,
    required this.groupId,
    required this.type,
    required this.title,
    this.deadline,
    this.completionMode = 'simple',
    this.targetCount,
    required this.assignedTo,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  /// Helper to check if this is a task assignment
  bool get isTask => type == 'task';

  /// Helper to check if this is a habit assignment
  bool get isHabit => type == 'habit';

  /// Helper to check if completion requires reaching a target count
  bool get isCountMode => completionMode == 'count';

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'type': type,
      'title': title,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'completionMode': completionMode,
      'targetCount': targetCount,
      'assignedTo': assignedTo,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupAssignmentModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDeadline;
    if (map['deadline'] is Timestamp) {
      parsedDeadline = (map['deadline'] as Timestamp).toDate();
    } else if (map['deadline'] is String) {
      parsedDeadline = DateTime.tryParse(map['deadline']);
    }

    DateTime parsedCreated = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreated = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreated = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    }

    List<String> assignedList = [];
    if (map['assignedTo'] is List) {
      assignedList = List<String>.from(map['assignedTo']);
    }

    return GroupAssignmentModel(
      id: docId,
      groupId: map['groupId'] ?? '',
      type: map['type'] ?? 'task',
      title: map['title'] ?? '',
      deadline: parsedDeadline,
      completionMode: map['completionMode'] ?? 'simple',
      targetCount: (map['targetCount'] as num?)?.toInt(),
      assignedTo: assignedList,
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'Admin',
      createdAt: parsedCreated,
    );
  }

  factory GroupAssignmentModel.fromFirestore(DocumentSnapshot doc) {
    return GroupAssignmentModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  GroupAssignmentModel copyWith({
    String? id,
    String? groupId,
    String? type,
    String? title,
    DateTime? deadline,
    String? completionMode,
    int? targetCount,
    List<String>? assignedTo,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    bool clearDeadline = false,
  }) {
    return GroupAssignmentModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      title: title ?? this.title,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      completionMode: completionMode ?? this.completionMode,
      targetCount: targetCount ?? this.targetCount,
      assignedTo: assignedTo ?? this.assignedTo,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
