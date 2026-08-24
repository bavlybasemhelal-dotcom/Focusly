import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Daily Nutrition Quality Log entry.
///
/// Firestore path: `users/{userId}/nutritionLog/{logId}` (isolated per-user).
/// Each user records one nutrition quality rating per day (rating 1 to 5).
class NutritionLogModel {
  final String id;
  final int rating; // 1 to 5 (1=Very Bad, 2=Unhealthy, 3=Average, 4=Very Good, 5=Excellent)
  final DateTime date; // Calendar date of the log
  final String? note; // Optional multiline notes (e.g. what was eaten)
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionLogModel({
    required this.id,
    required this.rating,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Maps rating (1-5) to corresponding emoji.
  /// 5→😊, 4→🙂, 3→😐, 2→😕, 1→😞
  static String getEmojiForRating(int? rating) {
    switch (rating) {
      case 5:
        return '😊';
      case 4:
        return '🙂';
      case 3:
        return '😐';
      case 2:
        return '😕';
      case 1:
        return '😞';
      default:
        return '⚪'; // Placeholder for no log
    }
  }

  /// Instance getter for this model's rating emoji.
  String get emoji => getEmojiForRating(rating);

  /// Localization key corresponding to rating quality label.
  static String getLabelKeyForRating(int rating) {
    switch (rating) {
      case 5:
        return 'nutrition_rating_5';
      case 4:
        return 'nutrition_rating_4';
      case 3:
        return 'nutrition_rating_3';
      case 2:
        return 'nutrition_rating_2';
      case 1:
        return 'nutrition_rating_1';
      default:
        return 'nutrition_rating_3';
    }
  }

  /// Instance getter for localization key.
  String get labelKey => getLabelKeyForRating(rating);

  /// Converts this model to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rating': rating,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Creates a NutritionLogModel from a Firestore document snapshot map.
  factory NutritionLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedDate = parseDate(map['date'], now);
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawRating = (map['rating'] as num?)?.toInt() ?? 3;
    // Ensure rating is clamped between 1 and 5
    final rating = rawRating.clamp(1, 5);

    return NutritionLogModel(
      id: docId,
      rating: rating,
      date: parsedDate,
      note: (map['note'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Returns a copy of this model with optional fields replaced.
  NutritionLogModel copyWith({
    String? id,
    int? rating,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNote = false,
  }) {
    return NutritionLogModel(
      id: id ?? this.id,
      rating: rating ?? this.rating,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rating == other.rating &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^ rating.hashCode ^ date.hashCode ^ (note?.hashCode ?? 0);
}
