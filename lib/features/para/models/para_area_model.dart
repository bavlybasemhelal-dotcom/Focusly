import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a PARA Area of Responsibility.
///
/// Areas are ongoing spheres of activity and standards with no target end date
/// (e.g. Health, Finance, Career, Family).
///
/// Stored in Firestore under: `users/{userId}/paraAreas/{areaId}`
class ParaAreaModel {
  final String id;
  final String title;
  final String emoji;
  final DateTime createdAt;

  const ParaAreaModel({
    required this.id,
    required this.title,
    this.emoji = '🎯',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ParaAreaModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return ParaAreaModel(
      id: docId,
      title: map['title'] ?? '',
      emoji: (map['emoji'] != null && (map['emoji'] as String).isNotEmpty)
          ? map['emoji']
          : '🎯',
      createdAt: parsedCreatedAt,
    );
  }

  ParaAreaModel copyWith({
    String? id,
    String? title,
    String? emoji,
    DateTime? createdAt,
  }) {
    return ParaAreaModel(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParaAreaModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          emoji == other.emoji;

  @override
  int get hashCode => id.hashCode ^ title.hashCode ^ emoji.hashCode;
}
