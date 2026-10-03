import '../../productivity/services/trash_service.dart';
import '../../../core/data/inbox_conversion_service.dart';
import '../../../core/data/completion_ledger.dart';
import 'dart:async';
import '../../../core/data/item_progress_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import '../widgets/task_count_dialog.dart';
import '../services/task_notification_service.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';
import '../../groups/services/challenge_service.dart';
import '../../groups/services/group_feed_service.dart';
import '../../skills/services/skills_service.dart';

/// Available view modes in the Tasks screen
enum TasksViewMode { list, matrix }

/// Notifier controller for TasksViewMode (Riverpod 3.x pattern)
class TasksViewModeNotifier extends Notifier<TasksViewMode> {
  @override
  TasksViewMode build() => TasksViewMode.list;

  void setMode(TasksViewMode mode) {
    state = mode;
  }
}

final tasksViewModeProvider =
    NotifierProvider<TasksViewModeNotifier, TasksViewMode>(
      TasksViewModeNotifier.new,
    );

/// Notifier controller for filtering tasks by category ID
class SelectedCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(currentUserIdProvider);
    return 'all';
  }

  void setFilter(String categoryId) {
    state = categoryId;
  }
}

final selectedCategoryFilterProvider =
    NotifierProvider<SelectedCategoryFilterNotifier, String>(
      SelectedCategoryFilterNotifier.new,
    );

/// Stream of task categories (default seeded + custom from Firestore)
///
/// DATA ISOLATION: Watches [currentUserIdProvider] so when the user logs out
/// or switches accounts, the stream subscription is immediately torn down
/// and rebuilt for the new user UID.
final categoriesProvider = StreamProvider<List<TaskCategory>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(TaskCategory.defaultCategories);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('categories')
        .snapshots()
        .map((snapshot) {
          final customCategories = snapshot.docs
              .map((doc) => TaskCategory.fromMap(doc.data(), doc.id))
              .toList();

          return [...TaskCategory.defaultCategories, ...customCategories];
        });
  } catch (_) {
    return Stream.value(TaskCategory.defaultCategories);
  }
});

/// Stream of all tasks for the authenticated user from Firestore
///
/// DATA ISOLATION: Strictly scoped to `users/{uid}/tasks`. Watching [currentUserIdProvider]
/// ensures that if Account A logs out and Account B logs in, Account A's tasks are
/// immediately dropped from memory and cannot leak to Account B.
final tasksStreamProvider = StreamProvider<List<TaskModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<TaskModel>[]);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  } catch (_) {
    return Stream.value([]);
  }
});

/// Controller handling task additions, edits, deletions, subtasks, and quadrant assignments
class TasksController {
  Future<void> cancelDeletedTaskReminders(String id) =>
      _notificationService.cancelTaskNotifications(id);
  Future<void> _validateProject(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> user,
    String? projectId,
  ) async {
    if (projectId == null || projectId.isEmpty) return;
    final project = await transaction.get(
      user.collection('paraProjects').doc(projectId),
    );
    if (!project.exists || project.data()?['deletionPending'] == true) {
      throw StateError('Project no longer exists');
    }
  }

  final TaskNotificationService _notificationService =
      TaskNotificationService();

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _tasksCollection {
    final uid = _currentUserId;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('tasks');
  }

  /// Adds a new task to Firestore and schedules its local reminder alerts
  Future<bool> addTask(
    TaskModel task,
    BuildContext context, {
    String? inboxId,
  }) async {
    final localizations = AppLocalizations.of(context);
    final col = _tasksCollection;
    if (col == null) return false;

    try {
      final docRef = col.doc(inboxId != null ? 'inbox_$inboxId' : null);
      final newTask = task.copyWith(id: docRef.id);
      if (inboxId != null) {
        await InboxConversionService(col.firestore).convert(
          uid: col.parent!.id,
          inboxId: inboxId,
          collection: 'tasks',
          data: newTask.toMap(),
        );
      } else {
        await col.firestore.runTransaction((transaction) async {
          await _validateProject(transaction, col.parent!, newTask.projectId);
          transaction.set(docRef, newTask.toMap());
        });
      }

      // Schedule notifications
      try {
        await _notificationService.scheduleTaskNotifications(
          newTask,
          localizations,
          uid: col.parent!.id,
        );
      } catch (e) {
        debugPrint('Task saved, but reminder scheduling failed: $e');
      }

      // Achievement check hook (Early bird, night owl, 20 tasks, etc.)
      if (_currentUserId == col.parent!.id) {
        ProgressService().checkAndUnlockAchievements(
          uid: col.parent!.id,
          context: context.mounted ? context : null,
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error adding task: $e');
      return false;
    }
  }

  /// Updates an existing task and reschedules its alerts
  Future<bool> updateTask(TaskModel task, BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final col = _tasksCollection;
    if (col == null) return false;

    try {
      final data = task.toMap()
        ..remove('done')
        ..remove('doneAt')
        ..remove('currentCount')
        ..remove('subtasks')
        ..remove('createdAt');
      await col.firestore.runTransaction((transaction) async {
        final source = await transaction.get(col.doc(task.id));
        if (!source.exists || source.data()?['deletionPending'] == true) {
          throw StateError('Task no longer exists');
        }
        await _validateProject(transaction, col.parent!, task.projectId);
        transaction.update(col.doc(task.id), data);
      });

      // Reschedule notifications
      try {
        await _notificationService.scheduleTaskNotifications(
          task,
          localizations,
          uid: col.parent!.id,
        );
      } catch (e) {
        debugPrint('Task saved, but reminder scheduling failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Error updating task: $e');
      return false;
    }
  }

  /// Deletes a task from Firestore and cancels its scheduled alerts
  Future<void> deleteTask(String taskId) async {
    final col = _tasksCollection;
    if (col == null) return;

    try {
      await TrashService(col.firestore).move(col.parent!.id, 'tasks', taskId);
      if (_currentUserId == col.parent!.id) {
        await _notificationService.cancelTaskNotifications(taskId);
      }
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  /// Toggles task done status
  Future<void> toggleTaskDone(TaskModel task, BuildContext context) async {
    final sessionUid = _currentUserId;
    int? count;
    if (task.completionMode == 'count') {
      count = await showTaskCountDialog(context, task);
      if (count == null || !context.mounted || _currentUserId != sessionUid) {
        return;
      }
    }
    final completed = count != null
        ? count >= (task.targetCount ?? 1)
        : !task.done;
    if (sessionUid == null) return;
    late TaskModel updated;
    try {
      final data = await ItemProgressService(
        FirebaseFirestore.instance,
      ).task(uid: sessionUid, id: task.id, done: completed, count: count);
      updated = TaskModel.fromMap(data, task.id);
      if (_currentUserId != sessionUid) return;
      await _notificationService.cancelTaskNotifications(task.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('task_save_error'))));
      }
      return;
    }
    if (_currentUserId != sessionUid) return;

    // =========================================================================
    // XP & ACHIEVEMENT HOOKS
    // NOTE: Group-assigned tasks explicitly BYPASS all personal XP awards.
    // =========================================================================
    if (updated.done) {
      if (updated.isGroupAssigned || updated.learningSource != null) {
        // Explicitly SKIP personal XP and skill XP for group-assigned tasks
        final ledger = CompletionLedger(FirebaseFirestore.instance);
        await ledger.award(
          uid: sessionUid,
          eventId: 'task_${updated.id}',
          sourceId: updated.id,
          sourceType: 'task',
          amount: 0,
          label: updated.title,
        );
        await ledger.syncGroups(uid: sessionUid, eventId: 'task_${updated.id}');
        debugPrint(
          'Group-assigned task completed ("${updated.title}") — skipping personal XP award.',
        );
      } else {
        // Normal personal task: Award standard task completion XP (+10 XP)
        {
          await ProgressService().awardXp(
            XpConstants.taskCompletion,
            source: 'Completed task: "${updated.title}"',
            sourceType: 'task',
            uid: sessionUid,
            sourceId: updated.id,
            eventId: 'task_${updated.id}',
            context: context.mounted ? context : null,
          );

          // Skill XP hook: Award skill XP based on task priority (High: 25, Medium: 15, Low: 10)
          final uid = sessionUid;
          {
            await SkillsService().awardTaskCompletionXp(
              uid: uid,
              task: updated,
              context: context.mounted ? context : null,
            );
          }
        }
      }

      // Group feed hook & Challenge progress sync
      GroupFeedService().pushToAllUserGroups(
        uid: sessionUid,
        type: 'task_milestone',
        message: 'Completed task: "${updated.title}"! 🎯',
        icon: '🎯',
      );
      ChallengeService().triggerProgressSync(uid: sessionUid);
    }
  }

  Future<void> _changeSubtasks(
    TaskModel task,
    List<SubtaskModel> Function(List<SubtaskModel>) operation,
  ) async {
    final collection = _tasksCollection;
    if (collection == null) throw StateError('Not signed in');
    final target = collection.doc(task.id);
    await collection.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(target);
      if (!snapshot.exists) throw StateError('Task no longer exists');
      final current = TaskModel.fromMap(snapshot.data()!, task.id);
      final changed = operation(current.subtasks);
      transaction.update(target, {
        'subtasks': changed.map((item) => item.toMap()).toList(),
      });
    });
  }

  Future<void> addSubtask(TaskModel task, String title) async {
    if (title.trim().isEmpty) return;
    final id = FirebaseFirestore.instance.collection('users').doc().id;
    await _changeSubtasks(
      task,
      (items) => [
        ...items,
        SubtaskModel(id: id, title: title.trim(), done: false),
      ],
    );
  }

  Future<void> toggleSubtask(TaskModel task, String subtaskId) =>
      _changeSubtasks(
        task,
        (items) => items
            .map(
              (item) =>
                  item.id == subtaskId ? item.copyWith(done: !item.done) : item,
            )
            .toList(),
      );
  Future<void> deleteSubtask(TaskModel task, String subtaskId) =>
      _changeSubtasks(
        task,
        (items) => items.where((item) => item.id != subtaskId).toList(),
      );
  Future<void> editSubtask(
    TaskModel task,
    String subtaskId,
    String title,
  ) async {
    if (title.trim().isEmpty) return;
    await _changeSubtasks(
      task,
      (items) => items
          .map(
            (item) => item.id == subtaskId
                ? item.copyWith(title: title.trim())
                : item,
          )
          .toList(),
    );
  }

  /// Moves a task into a specific Eisenhower Quadrant via drag & drop or quick select
  Future<void> moveTaskToQuadrant(
    TaskModel task,
    EisenhowerQuadrant quadrant,
    BuildContext context,
  ) async {
    final updated = applyQuadrantRule(task, quadrant);
    await updateTask(updated, context);
  }

  /// Adds a custom user category to Firestore
  Future<void> addCustomCategory(String name, int colorValue) async {
    final uid = _currentUserId;
    if (uid == null || name.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('categories')
          .add({
            'name': name.trim(),
            'colorValue': colorValue,
            'isDefault': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
      // Achievement check hook for creating custom category (org_custom_cat)
      ProgressService().checkAndUnlockAchievements(uid: uid);
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
  }
}

/// Global provider for Tasks Controller operations
final tasksControllerProvider = Provider<TasksController>((ref) {
  return TasksController();
});
