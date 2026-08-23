import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a PARA Project.
///
/// Projects are short-term efforts with a specific, measurable outcome and
/// an optional deadline, linked to an Area of Responsibility.
///
/// Stored in Firestore under: `users/{userId}/paraProjects/{projectId}`
class ParaProjectModel {
  final String id;
  final String title;
  final String areaId;
  final DateTime? deadline;
  final bool archived;
  final DateTime createdAt;

  const ParaProjectModel({
    required this.id,
    required this.title,
    required this.areaId,
    this.deadline,
    this.archived = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'areaId': areaId,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'archived': archived,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ParaProjectModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedDeadline;
    if (map['deadline'] is Timestamp) {
      parsedDeadline = (map['deadline'] as Timestamp).toDate();
    } else if (map['deadline'] is String) {
      parsedDeadline = DateTime.tryParse(map['deadline']);
    }

    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return ParaProjectModel(
      id: docId,
      title: map['title'] ?? '',
      areaId: map['areaId'] ?? '',
      deadline: parsedDeadline,
      archived: map['archived'] ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  ParaProjectModel copyWith({
    String? id,
    String? title,
    String? areaId,
    DateTime? deadline,
    bool? archived,
    DateTime? createdAt,
    bool clearDeadline = false,
  }) {
    return ParaProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      areaId: areaId ?? this.areaId,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParaProjectModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          areaId == other.areaId &&
          archived == other.archived;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ areaId.hashCode ^ archived.hashCode;
}
