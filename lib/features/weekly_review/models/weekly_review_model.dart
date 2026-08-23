import 'package:cloud_firestore/cloud_firestore.dart';

/// Pure calculation function checking if a Weekly Review is due.
///
/// A review is due if:
/// 1. The user has never completed a weekly review (`lastReviewDate == null`).
/// 2. It has been 7 or more days since `lastReviewDate`.
bool isReviewDue(DateTime? lastReviewDate, [DateTime? now]) {
  if (lastReviewDate == null) return true;
  final current = now ?? DateTime.now();
  final difference = current.difference(lastReviewDate);
  return difference.inDays >= 7;
}

/// Data model representing a completed Weekly Review session.
///
/// Stored in Firestore under: `users/{userId}/weeklyReviews/{reviewId}`
class WeeklyReviewModel {
  final String id;
  final DateTime date;
  final List<String> priorities; // Up to 3 main weekly priorities
  final DateTime createdAt;

  const WeeklyReviewModel({
    required this.id,
    required this.date,
    this.priorities = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': Timestamp.fromDate(date),
      'priorities': priorities,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory WeeklyReviewModel.fromMap(Map<String, dynamic> map, String docId) {
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

    final rawPriorities = map['priorities'];
    List<String> parsedPriorities = [];
    if (rawPriorities is List) {
      parsedPriorities = rawPriorities.map((e) => e.toString()).toList();
    }

    return WeeklyReviewModel(
      id: docId,
      date: parsedDate,
      priorities: parsedPriorities,
      createdAt: parsedCreatedAt,
    );
  }

  WeeklyReviewModel copyWith({
    String? id,
    DateTime? date,
    List<String>? priorities,
    DateTime? createdAt,
  }) {
    return WeeklyReviewModel(
      id: id ?? this.id,
      date: date ?? this.date,
      priorities: priorities ?? this.priorities,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
