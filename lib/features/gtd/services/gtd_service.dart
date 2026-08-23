import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../tasks/models/task_model.dart';
import '../models/inbox_item_model.dart';

/// Service managing GTD Inbox operations and specialized GTD task creation
/// (Waiting For, Someday/Maybe, Reference).
///
/// DATA ISOLATION GUARANTEE:
/// Strictly writes under `users/{uid}/inbox` and `users/{uid}/tasks`.
class GTDService {
  static final GTDService _instance = GTDService._internal();
  factory GTDService() => _instance;
  GTDService._internal();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _inboxCollection {
    final uid = _currentUid;
    final fs = _firestore;
    if (uid == null || uid.isEmpty || fs == null) return null;
    return fs.collection('users').doc(uid).collection('inbox');
  }

  CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    final uid = _currentUid;
    final fs = _firestore;
    if (uid == null || uid.isEmpty || fs == null) return null;
    return fs.collection('users').doc(uid).collection('tasks');
  }

  // ===========================================================================
  // 1. INBOX OPERATIONS
  // ===========================================================================

  /// Captures a raw thought into the user's Inbox (`users/{uid}/inbox`)
  Future<String?> addInboxItem(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final col = _inboxCollection;
    if (col == null) return null;

    final docRef = col.doc();
    final item = InboxItemModel(
      id: docRef.id,
      text: trimmed,
      processed: false,
      createdAt: DateTime.now(),
    );

    await docRef.set(item.toMap());
    return docRef.id;
  }

  /// Updates the processed status of an inbox item
  Future<void> markInboxProcessed(String itemId, {bool processed = true}) async {
    final col = _inboxCollection;
    if (col == null) return;
    await col.doc(itemId).update({'processed': processed});
  }

  /// Permanently deletes an inbox item
  Future<void> deleteInboxItem(String itemId) async {
    final col = _inboxCollection;
    if (col == null) return;
    await col.doc(itemId).delete();
  }

  // ===========================================================================
  // 2. GTD TASK DESTINATIONS (SOMEDAY, WAITING, REFERENCE)
  // ===========================================================================

  /// Creates a Someday/Maybe item in the Tasks collection
  Future<String?> createSomedayTask(
    String title, {
    String? notes,
    String? originalInboxItemId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final col = _tasksCollection;
    if (col == null) return null;

    final docRef = col.doc();
    final task = TaskModel(
      id: docRef.id,
      title: trimmed,
      notes: notes,
      categoryId: 'personal',
      priority: TaskPriority.low,
      date: DateTime.now(),
      done: false,
      createdAt: DateTime.now(),
      listType: 'someday',
    );

    await docRef.set(task.toMap());

    if (originalInboxItemId != null && originalInboxItemId.isNotEmpty) {
      await markInboxProcessed(originalInboxItemId, processed: true);
    }

    return docRef.id;
  }

  /// Creates a Waiting For item in the Tasks collection
  Future<String?> createWaitingTask(
    String title,
    String waitingFor, {
    String? notes,
    DateTime? waitingSince,
    String? originalInboxItemId,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedWaitingFor = waitingFor.trim();
    if (trimmedTitle.isEmpty || trimmedWaitingFor.isEmpty) return null;

    final col = _tasksCollection;
    if (col == null) return null;

    final docRef = col.doc();
    final task = TaskModel(
      id: docRef.id,
      title: trimmedTitle,
      notes: notes,
      categoryId: 'work',
      priority: TaskPriority.medium,
      date: DateTime.now(),
      done: false,
      createdAt: DateTime.now(),
      listType: 'waiting',
      waitingFor: trimmedWaitingFor,
      waitingSince: waitingSince ?? DateTime.now(),
    );

    await docRef.set(task.toMap());

    if (originalInboxItemId != null && originalInboxItemId.isNotEmpty) {
      await markInboxProcessed(originalInboxItemId, processed: true);
    }

    return docRef.id;
  }

  /// Creates a Reference item in the Tasks collection
  Future<String?> createReferenceTask(
    String title, {
    String? notes,
    String? originalInboxItemId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return null;

    final col = _tasksCollection;
    if (col == null) return null;

    final docRef = col.doc();
    final task = TaskModel(
      id: docRef.id,
      title: trimmed,
      notes: notes,
      categoryId: 'personal',
      priority: TaskPriority.low,
      date: DateTime.now(),
      done: false,
      createdAt: DateTime.now(),
      listType: 'reference',
    );

    await docRef.set(task.toMap());

    if (originalInboxItemId != null && originalInboxItemId.isNotEmpty) {
      await markInboxProcessed(originalInboxItemId, processed: true);
    }

    return docRef.id;
  }

  /// Promotes a Someday/Maybe item to a standard active Task
  Future<void> promoteSomedayToTask(
    String taskId, {
    required DateTime newDate,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final col = _tasksCollection;
    if (col == null) return;

    await col.doc(taskId).update({
      'listType': FieldValue.delete(),
      'date': Timestamp.fromDate(newDate),
      'priority': priority.name,
    });
  }

  /// Resolves a Waiting For task (marks done or converts to normal active task)
  Future<void> resolveWaitingTask(String taskId, {bool markDone = true}) async {
    final col = _tasksCollection;
    if (col == null) return;

    if (markDone) {
      await col.doc(taskId).update({
        'done': true,
      });
    } else {
      await col.doc(taskId).update({
        'listType': FieldValue.delete(),
        'waitingFor': FieldValue.delete(),
        'waitingSince': FieldValue.delete(),
      });
    }
  }

  /// Updates waiting task information (e.g. person being waited on)
  Future<void> updateWaitingTask(
    String taskId, {
    required String title,
    required String waitingFor,
  }) async {
    final col = _tasksCollection;
    if (col == null) return;

    await col.doc(taskId).update({
      'title': title.trim(),
      'waitingFor': waitingFor.trim(),
    });
  }

  /// Deletes a task by ID
  Future<void> deleteTask(String taskId) async {
    final col = _tasksCollection;
    if (col == null) return;
    await col.doc(taskId).delete();
  }
}
