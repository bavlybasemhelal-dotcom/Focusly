import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Central helper for writing notification logs to the user's Firestore collection.
///
/// Distinguishes between immediate delivered alerts and scheduled future reminders.
/// Firestore Path: `users/{uid}/notificationLog/{id}`
class NotificationLogger {
  static String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _currentUserId;
    if (uid == null) return null;
    try {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notificationLog');
    } catch (_) {
      return null;
    }
  }

  /// Logs a notification event into the user's notification history.
  static Future<void> logNotification({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    bool isScheduled = false,
    DateTime? scheduledFor,
  }) async {
    try {
      final col = _collection;
      if (col == null) return;

      await col.add({
        'title': title,
        'body': body,
        'type': type,
        'relatedId': relatedId,
        'read': false,
        'isScheduled': isScheduled,
        'scheduledFor':
            scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('==> [NotificationLogger] Logged notification (isScheduled: $isScheduled, scheduledFor: $scheduledFor)');
    } catch (e) {
      debugPrint('NotificationLogger.logNotification error: $e');
    }
  }
}
