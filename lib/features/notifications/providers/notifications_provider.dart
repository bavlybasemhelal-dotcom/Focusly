import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_log_model.dart';

/// StreamProvider listening to the user's notificationLog collection in Firestore.
final notificationLogsStreamProvider =
    StreamProvider<List<NotificationLogModel>>((ref) {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return Stream.value([]);
  }

  if (uid == null) {
    return Stream.value([]);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notificationLog')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationLogModel.fromFirestore(doc))
          .toList();
    });
  } catch (e) {
    debugPrint('notificationLogsStreamProvider error: $e');
    return Stream.value([]);
  }
});

/// Derived provider computing the count of unread notifications.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final logsAsync = ref.watch(notificationLogsStreamProvider);
  final logs = logsAsync.value ?? <NotificationLogModel>[];
  return logs.where((item) => !item.read).length;
});

/// Controller managing notification read states and removals.
final notificationsControllerProvider =
    Provider<NotificationsController>((ref) {
  return NotificationsController(ref);
});

class NotificationsController {
  final Ref ref;

  NotificationsController(this.ref);

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _collection {
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

  /// Marks a single notification as read.
  Future<void> markAsRead(String logId) async {
    try {
      final col = _collection;
      if (col == null) return;
      await col.doc(logId).update({'read': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Marks all unread notifications in the collection as read.
  Future<void> markAllAsRead() async {
    try {
      final col = _collection;
      if (col == null) return;

      final unreadDocs = await col.where('read', isEqualTo: false).get();
      if (unreadDocs.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Deletes a single notification record.
  Future<void> deleteNotification(String logId) async {
    try {
      final col = _collection;
      if (col == null) return;
      await col.doc(logId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Clears the entire notification history for the user.
  Future<void> clearAllNotifications() async {
    try {
      final col = _collection;
      if (col == null) return;

      final allDocs = await col.get();
      if (allDocs.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in allDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }
}
