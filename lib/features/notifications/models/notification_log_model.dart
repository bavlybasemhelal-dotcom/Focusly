import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a delivered/logged notification in Focusly.
///
/// Firestore path: `users/{userId}/notificationLog/{notificationId}` (per-user data isolation).
class NotificationLogModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'task_reminder' | 'event_reminder' | 'habit_reminder' | 'pomodoro' | 'group_activity' | 'system'
  final String? relatedId; // Target Task ID, Event ID, Habit ID, or Group ID
  final bool read;
  final DateTime createdAt;

  const NotificationLogModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.read = false,
    required this.createdAt,
  });

  /// Factory deserializer from Firestore DocumentSnapshot
  factory NotificationLogModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return NotificationLogModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'system',
      relatedId: data['relatedId'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Deserializer from Map
  factory NotificationLogModel.fromMap(Map<String, dynamic> data, String id) {
    return NotificationLogModel(
      id: id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'system',
      relatedId: data['relatedId'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] is String
              ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  /// Serializer to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'relatedId': relatedId,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Copy with modifications
  NotificationLogModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? relatedId,
    bool? read,
    DateTime? createdAt,
  }) {
    return NotificationLogModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      relatedId: relatedId ?? this.relatedId,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
