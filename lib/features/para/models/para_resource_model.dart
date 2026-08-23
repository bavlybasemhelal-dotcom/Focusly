import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a PARA Resource.
///
/// Resources are topics or themes of ongoing interest, reference materials,
/// notes, bookmarks, and useful knowledge assets.
///
/// Stored in Firestore under: `users/{userId}/paraResources/{resourceId}`
class ParaResourceModel {
  final String id;
  final String title;
  final String? notes;
  final List<String> tags;
  final bool archived;
  final DateTime createdAt;

  const ParaResourceModel({
    required this.id,
    required this.title,
    this.notes,
    this.tags = const [],
    this.archived = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'tags': tags,
      'archived': archived,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ParaResourceModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    List<String> parsedTags = [];
    if (map['tags'] is List) {
      parsedTags = (map['tags'] as List)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return ParaResourceModel(
      id: docId,
      title: map['title'] ?? '',
      notes: map['notes'],
      tags: parsedTags,
      archived: map['archived'] ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  ParaResourceModel copyWith({
    String? id,
    String? title,
    String? notes,
    List<String>? tags,
    bool? archived,
    DateTime? createdAt,
    bool clearNotes = false,
  }) {
    return ParaResourceModel(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      tags: tags ?? this.tags,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParaResourceModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          notes == other.notes &&
          archived == other.archived;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ (notes?.hashCode ?? 0) ^ archived.hashCode;
}
