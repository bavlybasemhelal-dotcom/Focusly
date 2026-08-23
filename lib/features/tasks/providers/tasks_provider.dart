import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import '../services/task_notification_service.dart';

/// Available view modes in the Tasks screen
enum TasksViewMode {
  list,
  matrix,
}

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
  String build() => 'all';

  void setFilter(String categoryId) {
    state = categoryId;
  }
}

final selectedCategoryFilterProvider =
    NotifierProvider<SelectedCategoryFilterNotifier, String>(
  SelectedCategoryFilterNotifier.new,
);

/// Stream of task categories (default seeded + custom from Firestore)
final categoriesProvider = StreamProvider<List<TaskCategory>>((ref) {
  User? user;
  try {
    user = FirebaseAuth.instance.currentUser;
  } catch (_) {}

  if (user == null) {
    return Stream.value(TaskCategory.defaultCategories);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('categories')
        .snapshots()
        .map((snapshot) {
      final customCategories = snapshot.docs
          .map((doc) => TaskCategory.fromMap(doc.data(), doc.id))
          .toList();

      return [...TaskCategory.defaultCategories, ...customCategories];
    }).handleError((_) => TaskCategory.defaultCategories);
  } catch (_) {
    return Stream.value(TaskCategory.defaultCategories);
  }
});

/// Stream of all tasks for the authenticated user from Firestore
final tasksStreamProvider = StreamProvider<List<TaskModel>>((ref) {
  User? user;
  try {
    user = FirebaseAuth.instance.currentUser;
  } catch (_) {}

  if (user == null) {
    return Stream.value([]);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('tasks')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => TaskModel.fromMap(doc.data(), doc.id))
          .toList();
    }).handleError((e) {
      debugPrint('Firestore tasks stream error: $e');
      return <TaskModel>[];
    });
  } catch (_) {
    return Stream.value([]);
  }
});

/// Controller handling task additions, edits, deletions, subtasks, and quadrant assignments
class TasksController {
  final TaskNotificationService _notificationService = TaskNotificationService();

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
  Future<void> addTask(TaskModel task, BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final col = _tasksCollection;
    if (col == null) return;

    try {
      final docRef = col.doc();
      final newTask = task.copyWith(id: docRef.id);
      await docRef.set(newTask.toMap());

      // Schedule notifications
      await _notificationService.scheduleTaskNotifications(newTask, localizations);
    } catch (e) {
      debugPrint('Error adding task: $e');
    }
  }

  /// Updates an existing task and reschedules its alerts
  Future<void> updateTask(TaskModel task, BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final col = _tasksCollection;
    if (col == null) return;

    try {
      await col.doc(task.id).update(task.toMap());

      // Reschedule notifications
      await _notificationService.scheduleTaskNotifications(task, localizations);
    } catch (e) {
      debugPrint('Error updating task: $e');
    }
  }

  /// Deletes a task from Firestore and cancels its scheduled alerts
  Future<void> deleteTask(String taskId) async {
    final col = _tasksCollection;
    if (col == null) return;

    try {
      await col.doc(taskId).delete();
      await _notificationService.cancelTaskNotifications(taskId);
    } catch (e) {
      debugPrint('Error deleting task: $e');
    }
  }

  /// Toggles task done status
  Future<void> toggleTaskDone(TaskModel task, BuildContext context) async {
    final updated = task.copyWith(done: !task.done);
    await updateTask(updated, context);
  }

  /// Appends a new subtask item
  Future<void> addSubtask(TaskModel task, String title) async {
    if (title.trim().isEmpty) return;
    final newSubtask = SubtaskModel(
      id: UniqueKey().toString(),
      title: title.trim(),
      done: false,
    );
    final updatedSubtasks = [...task.subtasks, newSubtask];

    final col = _tasksCollection;
    if (col == null) return;
    try {
      await col.doc(task.id).update({'subtasks': updatedSubtasks.map((s) => s.toMap()).toList()});
    } catch (e) {
      debugPrint('Error adding subtask: $e');
    }
  }

  /// Toggles a specific subtask's completion checkbox
  Future<void> toggleSubtask(TaskModel task, String subtaskId) async {
    final updatedSubtasks = task.subtasks.map((s) {
      if (s.id == subtaskId) {
        return s.copyWith(done: !s.done);
      }
      return s;
    }).toList();

    final col = _tasksCollection;
    if (col == null) return;
    try {
      await col.doc(task.id).update({'subtasks': updatedSubtasks.map((s) => s.toMap()).toList()});
    } catch (e) {
      debugPrint('Error toggling subtask: $e');
    }
  }

  /// Deletes a subtask item from a task
  Future<void> deleteSubtask(TaskModel task, String subtaskId) async {
    final updatedSubtasks = task.subtasks.where((s) => s.id != subtaskId).toList();

    final col = _tasksCollection;
    if (col == null) return;
    try {
      await col.doc(task.id).update({'subtasks': updatedSubtasks.map((s) => s.toMap()).toList()});
    } catch (e) {
      debugPrint('Error deleting subtask: $e');
    }
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
    } catch (e) {
      debugPrint('Error adding category: $e');
    }
  }
}

/// Global provider for Tasks Controller operations
final tasksControllerProvider = Provider<TasksController>((ref) {
  return TasksController();
});
