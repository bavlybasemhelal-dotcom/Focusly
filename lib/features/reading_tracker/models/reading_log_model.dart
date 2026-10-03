import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a reading activity log entry.
///
/// Logged whenever pages are read on a book to support streak tracking and analytics.
/// Stored in Firestore under: `users/{userId}/readingLogs/{logId}`
class ReadingLogModel {
  final String id;
  final String bookId;
  final int pagesRead;
  final DateTime date;
  final DateTime createdAt;

  const ReadingLogModel({
    required this.id,
    required this.bookId,
    required this.pagesRead,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'pagesRead': pagesRead,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory ReadingLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    return ReadingLogModel(
      id: docId,
      bookId: map['bookId'] ?? '',
      pagesRead: (map['pagesRead'] as num?)?.toInt() ?? 0,
      date: parseDate(map['date'], now),
      createdAt: parseDate(map['createdAt'], now),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          bookId == other.bookId &&
          pagesRead == other.pagesRead &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day;

  @override
  int get hashCode =>
      id.hashCode ^ bookId.hashCode ^ pagesRead.hashCode ^ date.day.hashCode;
}
