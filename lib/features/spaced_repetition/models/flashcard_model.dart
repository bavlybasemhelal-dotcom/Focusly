import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Spaced Repetition (SM-2) Flashcard.
///
/// Firestore path: `users/{userId}/flashcards/{cardId}` (isolated per-user).
class FlashcardModel {
  final String id;
  final String front; // Question / Concept prompt
  final String back; // Answer / Explanation
  final int interval; // Days until next review (starts at 0 for new cards)
  final int repetitions; // Consecutive successful reviews (starts at 0)
  final double easeFactor; // SM-2 ease multiplier (starts at 2.5)
  final String
  dueDate; // Formatted 'yyyy-MM-dd', defaults to today for new cards
  final DateTime createdAt;
  final DateTime updatedAt;

  const FlashcardModel({
    required this.id,
    required this.front,
    required this.back,
    this.interval = 0,
    this.repetitions = 0,
    this.easeFactor = 2.5,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Helper getter returning whether the card is due for review today or overdue.
  bool get isDue => isDueOn(DateTime.now());

  bool isDueOn(DateTime now) {
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return dueDate.compareTo(todayStr) <= 0;
  }

  /// Calculates number of days remaining until due (negative if overdue, 0 if due today, >0 if due in future).
  int get dueDaysRemaining {
    final parsed = DateTime.tryParse(dueDate);
    if (parsed == null) return 0;
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(parsed.year, parsed.month, parsed.day);
    return targetDate.difference(todayDate).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'interval': interval,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'dueDate': dueDate,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory FlashcardModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return FlashcardModel(
      id: docId,
      front: (map['front'] as String?)?.trim() ?? '',
      back: (map['back'] as String?)?.trim() ?? '',
      interval: (map['interval'] as num?)?.toInt() ?? 0,
      repetitions: (map['repetitions'] as num?)?.toInt() ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      dueDate: (map['dueDate'] as String?)?.trim() ?? todayStr,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  FlashcardModel copyWith({
    String? id,
    String? front,
    String? back,
    int? interval,
    int? repetitions,
    double? easeFactor,
    String? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FlashcardModel(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      easeFactor: easeFactor ?? this.easeFactor,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          front == other.front &&
          back == other.back &&
          interval == other.interval &&
          repetitions == other.repetitions &&
          (easeFactor - other.easeFactor).abs() < 0.0001 &&
          dueDate == other.dueDate;

  @override
  int get hashCode =>
      id.hashCode ^
      front.hashCode ^
      back.hashCode ^
      interval.hashCode ^
      repetitions.hashCode ^
      easeFactor.hashCode ^
      dueDate.hashCode;
}
