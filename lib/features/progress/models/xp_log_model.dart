import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single XP gain event in the user's XP audit log.
///
/// Persisted under `users/{uid}/xpLog/{logId}` to give users complete transparency
/// into how and where their XP was earned.
class XpLogModel {
  final String id;
  final int amount;
  final String source;
  final String? sourceType;
  final DateTime createdAt;

  const XpLogModel({
    required this.id,
    required this.amount,
    required this.source,
    this.sourceType,
    required this.createdAt,
  });

  factory XpLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parsedDate = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      parsedDate = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      parsedDate =
          DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    }

    return XpLogModel(
      id: doc.id,
      amount: data['amount'] as int? ?? 0,
      source: data['source'] as String? ?? 'Productivity action',
      sourceType: data['sourceType'] as String?,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'source': source,
      'sourceType': sourceType,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Returns a representative emoji for the XP source category
  String get sourceEmoji {
    switch (sourceType) {
      case 'task':
        return '🎯';
      case 'habit':
        return '🔥';
      case 'pomodoro':
        return '🍅';
      case 'reading':
        return '📚';
      case 'checkin':
        return '⚡';
      case 'water':
        return '💧';
      case 'sleep':
        return '🌙';
      case 'learning_path':
        return '🗺️';
      case 'flashcards':
        return '🗂️';
      case 'rituals':
        return '🌅';
      case 'weekly_review':
        return '📊';
      default:
        return '✨';
    }
  }
}
