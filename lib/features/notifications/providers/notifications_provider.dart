import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/data/firestore_provider.dart';
import '../models/notification_log_model.dart';

/// StreamProvider listening to the user's notificationLog collection in Firestore.
final notificationLogsStreamProvider =
    StreamProvider.autoDispose<List<NotificationLogModel>>((ref) {
      final uid = ref.watch(currentUserIdProvider);

      if (uid == null) {
        return Stream.value([]);
      }

      try {
        return ref
            .watch(firestoreProvider)
            .collection('users')
            .doc(uid)
            .collection('notificationLog')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => NotificationLogModel.fromFirestore(doc))
                  .toList();
            });
      } catch (e) {
        return Stream.error(e);
      }
    });

/// Derived provider computing the count of unread notifications.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final logsAsync = ref.watch(notificationLogsStreamProvider);
  final logs = logsAsync.value ?? <NotificationLogModel>[];
  return logs.where((item) => !item.read).length;
});

/// Controller managing notification read states and removals.
final notificationsControllerProvider = Provider<NotificationsController>((
  ref,
) {
  return NotificationsController(ref);
});

class NotificationsController {
  final Ref ref;

  NotificationsController(this.ref);

  String? get _currentUserId {
    return ref.read(currentUserIdProvider);
  }

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _currentUserId;
    if (uid == null) return null;
    try {
      return ref
          .read(firestoreProvider)
          .collection('users')
          .doc(uid)
          .collection('notificationLog');
    } catch (_) {
      return null;
    }
  }

  /// Marks a single notification as read.
  Future<bool> markAsRead(String logId) async {
    try {
      final col = _collection;
      if (col == null) return false;
      await col.doc(logId).update({'read': true});
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Marks all unread notifications in the collection as read.
  Future<bool> markAllAsRead() async {
    try {
      final col = _collection;
      if (col == null) return false;

      while (true) {
        final unreadDocs = await col
            .where('read', isEqualTo: false)
            .limit(200)
            .get();
        if (unreadDocs.docs.isEmpty) break;
        final batch = ref.read(firestoreProvider).batch();
        for (final doc in unreadDocs.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        if (_currentUserId != col.parent?.id) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Deletes a single notification record.
  Future<bool> deleteNotification(String logId) async {
    try {
      final col = _collection;
      if (col == null) return false;
      await col.doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  /// Clears the entire notification history for the user.
  Future<bool> clearAllNotifications() async {
    try {
      final col = _collection;
      if (col == null) return false;

      while (true) {
        final allDocs = await col.limit(200).get();
        if (allDocs.docs.isEmpty) break;
        final batch = ref.read(firestoreProvider).batch();
        for (final doc in allDocs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (_currentUserId != col.parent?.id) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
      return false;
    }
  }
}
