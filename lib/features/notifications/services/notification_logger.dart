import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/data/completion_ledger.dart';

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

  /// Logs a notification event into the user's notification history.
  static Future<void> logNotification({
    required String title,
    required String body,
    required String type,
    String? relatedId,
    bool isScheduled = false,
    DateTime? scheduledFor,
    String? uid,
  }) async {
    try {
      final account = uid ?? _currentUserId;
      if (account == null || _currentUserId != account) return;
      final col = FirebaseFirestore.instance
          .collection('users')
          .doc(account)
          .collection('notificationLog');
      final id = CompletionLedger.eventKey(
        '$type:$relatedId:${scheduledFor?.toIso8601String() ?? DateTime.now().microsecondsSinceEpoch}',
      );
      final previous = await col.doc(id).get();
      if (previous.exists) return;
      await col.doc(id).set({
        'title': title,
        'body': body,
        'type': type,
        'relatedId': relatedId,
        'read': false,
        'isScheduled': isScheduled,
        'status': isScheduled ? 'scheduled' : 'sentToOs',
        'scheduledFor': scheduledFor != null
            ? Timestamp.fromDate(scheduledFor)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '==> [NotificationLogger] Logged notification (isScheduled: $isScheduled, scheduledFor: $scheduledFor)',
      );
    } catch (e) {
      debugPrint('NotificationLogger.logNotification error: $e');
    }
  }
}
