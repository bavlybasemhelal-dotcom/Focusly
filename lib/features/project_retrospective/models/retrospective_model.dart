import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Project Retrospective (post-mortem reflection).
///
/// Records reflection details after wrapping up a PARA Project:
/// - [projectId]: ID of the associated PARA Project.
/// - [date]: Date when the retrospective was conducted (defaults to today).
/// - [wentWell]: Things that went well during project execution.
/// - [toImprove]: Obstacles, pitfalls, or areas needing improvement.
/// - [learnings]: Lessons learned and actionable takeaways for future projects.
/// - [createdAt]: Document creation timestamp.
/// - [updatedAt]: Document last modification timestamp.
///
/// Firestore path: `users/{userId}/retrospectives/{retroId}` (isolated per-user).
class RetrospectiveModel {
  final String id;
  final String projectId;
  final DateTime date;
  final String wentWell;
  final String toImprove;
  final String learnings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RetrospectiveModel({
    required this.id,
    required this.projectId,
    required this.date,
    required this.wentWell,
    required this.toImprove,
    required this.learnings,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Serializes model to a Firestore-compatible Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'date': Timestamp.fromDate(date),
      'wentWell': wentWell,
      'toImprove': toImprove,
      'learnings': learnings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore document snapshot into a [RetrospectiveModel].
  factory RetrospectiveModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedDate = parseDate(map['date'], now);
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    return RetrospectiveModel(
      id: docId,
      projectId: (map['projectId'] as String?)?.trim() ?? '',
      date: parsedDate,
      wentWell: (map['wentWell'] as String?)?.trim() ?? '',
      toImprove: (map['toImprove'] as String?)?.trim() ?? '',
      learnings: (map['learnings'] as String?)?.trim() ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this [RetrospectiveModel] with optional field overrides.
  RetrospectiveModel copyWith({
    String? id,
    String? projectId,
    DateTime? date,
    String? wentWell,
    String? toImprove,
    String? learnings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RetrospectiveModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      wentWell: wentWell ?? this.wentWell,
      toImprove: toImprove ?? this.toImprove,
      learnings: learnings ?? this.learnings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RetrospectiveModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          projectId == other.projectId &&
          date == other.date &&
          wentWell == other.wentWell &&
          toImprove == other.toImprove &&
          learnings == other.learnings;

  @override
  int get hashCode =>
      id.hashCode ^
      projectId.hashCode ^
      date.hashCode ^
      wentWell.hashCode ^
      toImprove.hashCode ^
      learnings.hashCode;
}
