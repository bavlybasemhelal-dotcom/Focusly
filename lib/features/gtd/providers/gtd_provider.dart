import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/inbox_item_model.dart';

FirebaseFirestore? get _firestoreInstance {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

/// Stream of all raw captured thoughts in the current user's Inbox
///
/// DATA ISOLATION: Watches [currentUserIdProvider] so inbox items are completely
/// partitioned per authenticated user.
final inboxStreamProvider =
    StreamProvider.autoDispose<List<InboxItemModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<InboxItemModel>[]);
  }

  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value(<InboxItemModel>[]);

  return firestore
      .collection('users')
      .doc(uid)
      .collection('inbox')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => InboxItemModel.fromMap(doc.data(), doc.id))
        .toList();
  });
});

/// Count of unprocessed inbox items (for the Navigation Drawer badge)
final unprocessedInboxCountProvider = Provider.autoDispose<int>((ref) {
  final inboxAsync = ref.watch(inboxStreamProvider);
  return inboxAsync.when(
    data: (items) => items.where((item) => !item.processed).length,
    loading: () => 0,
    error: (err, stack) => 0,
  );
});

/// Stream of GTD "Waiting For" tasks
final waitingTasksStreamProvider = Provider.autoDispose<AsyncValue<List<TaskModel>>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.whenData((tasks) {
    return tasks
        .where((t) => t.listType == 'waiting' && !t.done)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

/// Stream of GTD "Someday / Maybe" tasks
final somedayTasksStreamProvider = Provider.autoDispose<AsyncValue<List<TaskModel>>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.whenData((tasks) {
    return tasks
        .where((t) => t.listType == 'someday' && !t.done)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});

/// Stream of GTD "Reference" items
final referenceTasksStreamProvider = Provider.autoDispose<AsyncValue<List<TaskModel>>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  return tasksAsync.whenData((tasks) {
    return tasks
        .where((t) => t.listType == 'reference')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
});
