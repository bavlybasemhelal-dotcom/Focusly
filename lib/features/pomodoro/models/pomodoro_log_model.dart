import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a logged Focus Session (Pomodoro work phase) in Focusly.
///
/// Records actual focused duration, linked tasks, self-reported distraction count,
/// and whether the session was full or partial.
class PomodoroLogModel {
  final String id;
  final DateTime date;
  final String? linkedTaskId;
  final String taskTitle;
  final int durationMinutes; // Actual focused minutes
  final int durationSeconds; // Actual focused seconds
  final int distractionCount;
  final bool partial; // True if reset/stopped early (with at least 5s focused)
  final DateTime createdAt;

  const PomodoroLogModel({
    required this.id,
    required this.date,
    this.linkedTaskId,
    required this.taskTitle,
    required this.durationMinutes,
    required this.durationSeconds,
    this.distractionCount = 0,
    this.partial = false,
    required this.createdAt,
  });

  /// Factory constructor from Firestore snapshot
  factory PomodoroLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['date'] is Timestamp) {
      parsedDate = (data['date'] as Timestamp).toDate();
    } else if (data['date'] is String) {
      parsedDate = DateTime.tryParse(data['date'] as String) ?? DateTime.now();
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedCreatedAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedCreatedAt =
          DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    }

    return PomodoroLogModel(
      id: doc.id,
      date: parsedDate,
      linkedTaskId: data['linkedTaskId'] as String?,
      taskTitle: data['taskTitle'] as String? ?? 'Focus Session',
      durationMinutes: data['durationMinutes'] as int? ?? 0,
      durationSeconds: data['durationSeconds'] as int? ?? 0,
      distractionCount: data['distractionCount'] as int? ?? 0,
      partial: data['partial'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  /// Serializes the log entry for Firestore persistence
  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'linkedTaskId': linkedTaskId,
      'taskTitle': taskTitle,
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'distractionCount': distractionCount,
      'partial': partial,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
