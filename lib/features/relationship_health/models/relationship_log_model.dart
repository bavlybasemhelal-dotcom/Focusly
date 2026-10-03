import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a qualitative interaction log with a contact.
///
/// Firestore path: `users/{userId}/relationshipLogs/{logId}` (isolated per-user).
class RelationshipLogModel {
  final String id;
  final String contactId; // Links to ContactModel.id
  final DateTime date; // Date of interaction
  final int rating; // 1-5 star quality rating (default 5)
  final String? notes; // Optional multiline notes/takeaways
  final DateTime createdAt;
  final DateTime updatedAt;

  const RelationshipLogModel({
    required this.id,
    required this.contactId,
    required this.date,
    this.rating = 5,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contactId': contactId,
      'date': Timestamp.fromDate(date),
      'rating': rating,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RelationshipLogModel.fromMap(Map<String, dynamic> map, String docId) {
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

    final rawRating = (map['rating'] as num?)?.toInt() ?? 5;
    final rating = rawRating.clamp(1, 5);

    return RelationshipLogModel(
      id: docId,
      contactId: (map['contactId'] as String?)?.trim() ?? '',
      date: parsedDate,
      rating: rating,
      notes: (map['notes'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  RelationshipLogModel copyWith({
    String? id,
    String? contactId,
    DateTime? date,
    int? rating,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNotes = false,
  }) {
    return RelationshipLogModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      date: date ?? this.date,
      rating: rating ?? this.rating,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelationshipLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          contactId == other.contactId &&
          date == other.date &&
          rating == other.rating &&
          notes == other.notes;

  @override
  int get hashCode =>
      id.hashCode ^
      contactId.hashCode ^
      date.hashCode ^
      rating.hashCode ^
      (notes?.hashCode ?? 0);
}
