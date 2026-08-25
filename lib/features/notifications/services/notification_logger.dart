import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Central helper for writing delivered notification logs to the user's Firestore collection.
///
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
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationLogger.logNotification error: $e');
    }
  }
}
