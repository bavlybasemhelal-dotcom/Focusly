import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Daily Gratitude Log entry.
///
/// TODO: The future "Gratitude Log" feature will build its own list/browsing screen
/// directly on top of this same collection: `users/{userId}/gratitude/{gratitudeId}`.
/// Keep this exact schema (`date, item1, item2, item3, createdAt, updatedAt`).
class GratitudeModel {
  final String id;
  final DateTime date;
  final String item1;
  final String item2;
  final String item3;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GratitudeModel({
    required this.id,
    required this.date,
    required this.item1,
    required this.item2,
    required this.item3,
    required this.createdAt,
    required this.updatedAt,
  });

  String get combinedText => '$item1 • $item2 • $item3';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'item1': item1,
      'item2': item2,
      'item3': item3,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory GratitudeModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedDate;
    if (map['date'] is Timestamp) {
      parsedDate = (map['date'] as Timestamp).toDate();
    } else if (map['date'] is String) {
      parsedDate = DateTime.tryParse(map['date']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
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

    return GratitudeModel(
      id: docId,
      date: parsedDate,
      item1: map['item1'] ?? '',
      item2: map['item2'] ?? '',
      item3: map['item3'] ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  GratitudeModel copyWith({
    String? id,
    DateTime? date,
    String? item1,
    String? item2,
    String? item3,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return GratitudeModel(
      id: id ?? this.id,
      date: date ?? this.date,
      item1: item1 ?? this.item1,
      item2: item2 ?? this.item2,
      item3: item3 ?? this.item3,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
