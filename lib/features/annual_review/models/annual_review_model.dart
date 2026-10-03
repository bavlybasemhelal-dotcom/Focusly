import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a yearly reflection review in Focusly.
///
/// Features 4 guided reflection questions:
/// - [q1]: Biggest Achievement (🏆)
/// - [q2]: Biggest Obstacle and How Handled (🚧)
/// - [q3]: Top Lessons Learned (🧠)
/// - [q4]: Plan/Vision for Next Year (🚀)
///
/// Stored in Firestore under `users/{uid}/annualReviews/{reviewId}`.
class AnnualReviewModel {
  final String id;
  final int year;
  final String q1;
  final String q2;
  final String q3;
  final String q4;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AnnualReviewModel({
    required this.id,
    required this.year,
    required this.q1,
    required this.q2,
    required this.q3,
    required this.q4,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Converts the model to a Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'q1': q1,
      'q2': q2,
      'q3': q3,
      'q4': q4,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Factory constructor from a Firestore document snapshot
  factory AnnualReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AnnualReviewModel.fromMap(data, doc.id);
  }

  /// Factory constructor from Map and docId
  factory AnnualReviewModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt =
          DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
    }

    DateTime parsedUpdatedAt = DateTime.now();
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt =
          DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now();
    }

    return AnnualReviewModel(
      id: docId,
      year: (map['year'] as num?)?.toInt() ?? DateTime.now().year,
      q1: map['q1'] as String? ?? '',
      q2: map['q2'] as String? ?? '',
      q3: map['q3'] as String? ?? '',
      q4: map['q4'] as String? ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this model with optional updated values
  AnnualReviewModel copyWith({
    String? id,
    int? year,
    String? q1,
    String? q2,
    String? q3,
    String? q4,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnualReviewModel(
      id: id ?? this.id,
      year: year ?? this.year,
      q1: q1 ?? this.q1,
      q2: q2 ?? this.q2,
      q3: q3 ?? this.q3,
      q4: q4 ?? this.q4,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
