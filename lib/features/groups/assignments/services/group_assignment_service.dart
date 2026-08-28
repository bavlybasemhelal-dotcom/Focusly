import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../habits/models/habit_model.dart';
import '../../../tasks/models/task_model.dart';
import '../../models/group_member_model.dart';
import '../../services/group_feed_service.dart';
import '../models/assignment_completion_model.dart';
import '../models/group_assignment_model.dart';

/// Service managing Group Assignments: creation, member synchronization,
/// individual completion tracking, and group feed announcements.
class GroupAssignmentService {
  static final GroupAssignmentService _instance = GroupAssignmentService._internal();
  factory GroupAssignmentService() => _instance;
  GroupAssignmentService._internal();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Creates a new group assignment and distributes locked task/habit items
  /// to each selected member's personal collection in Firestore.
  Future<void> createAssignment({
    required String groupId,
    required String type, // 'task' | 'habit'
    required String title,
    required DateTime? deadline,
    required String completionMode, // 'simple' | 'count'
    required int? targetCount,
    required List<GroupMemberModel> selectedMembers,
  }) async {
    final firestore = _firestore;
    if (firestore == null) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    final adminUid = currentUser?.uid ?? '';
    final adminName = (currentUser?.displayName?.trim().isNotEmpty == true)
        ? currentUser!.displayName!
        : 'Admin';

    final now = DateTime.now();
    final groupRef = firestore.collection('groups').doc(groupId);
    final assignmentRef = groupRef.collection('assignments').doc();
    final assignmentId = assignmentRef.id;

    final assignedUids = selectedMembers.map((m) => m.uid).toList();

    final assignment = GroupAssignmentModel(
      id: assignmentId,
      groupId: groupId,
      type: type,
      title: title.trim(),
      deadline: deadline,
      completionMode: completionMode,
      targetCount: completionMode == 'count' ? targetCount : null,
      assignedTo: assignedUids,
      createdBy: adminUid,
      createdByName: adminName,
      createdAt: now,
    );

    try {
      // Use WriteBatch for atomic creation across the group assignment and member collections
      final batch = firestore.batch();

      // 1. Save Group Assignment Document
      batch.set(assignmentRef, assignment.toMap());

      // 2. Create Completion Tracker Document + Personal Task/Habit for each assigned member
      for (final member in selectedMembers) {
        final completionRef = assignmentRef.collection('completions').doc(member.uid);
        final completionDoc = AssignmentCompletionModel(
          uid: member.uid,
          memberName: member.name,
          status: 'pending',
          currentCount: 0,
          completedAt: null,
        );
        batch.set(completionRef, completionDoc.toMap());

        if (type == 'task') {
          // Write locked task to member's personal collection
          final memberTaskRef = firestore
              .collection('users')
              .doc(member.uid)
              .collection('tasks')
              .doc();

          final memberTask = TaskModel(
            id: memberTaskRef.id,
            title: title.trim(),
            categoryId: 'work',
            priority: TaskPriority.medium,
            date: deadline ?? now,
            deadline: deadline,
            done: false,
            createdAt: now,
            groupAssignmentId: assignmentId,
            assignedByGroupId: groupId,
            assignedByName: adminName,
            locked: true,
            completionMode: completionMode,
            targetCount: completionMode == 'count' ? targetCount : null,
            currentCount: 0,
          );

          batch.set(memberTaskRef, memberTask.toMap());
        } else {
          // Write locked habit to member's personal collection
          // For count-mode habits: instead of normal 7-day week grid, habit works toward targetCount
          final memberHabitRef = firestore
              .collection('users')
              .doc(member.uid)
              .collection('habits')
              .doc();

          final memberHabit = HabitModel(
            id: memberHabitRef.id,
            title: title.trim(),
            days: List<bool>.filled(7, false),
            streak: 0,
            baseStreak: 0,
            resetDay: DateTime.saturday,
            autoReset: false, // Bypasses normal weekly auto-reset for count mode
            lastResetDate: now,
            createdAt: deadline ?? now,
            groupAssignmentId: assignmentId,
            assignedByGroupId: groupId,
            assignedByName: adminName,
            locked: true,
            completionMode: completionMode,
            targetCount: completionMode == 'count' ? targetCount : null,
            currentCount: 0,
            isCompleted: false,
          );

          batch.set(memberHabitRef, memberHabit.toMap());
        }
      }

      await batch.commit();

      // 3. Post Announcement Feed Entry to the Group
      final memberCountText = selectedMembers.length == 1
          ? '1 member'
          : '${selectedMembers.length} members';

      await GroupFeedService().postToGroup(
        groupId: groupId,
        type: 'assignment',
        message: '$adminName assigned "$title" to $memberCountText 📋',
        icon: '📋',
      );
    } catch (e) {
      debugPrint('Error creating group assignment: $e');
      rethrow;
    }
  }

  /// Syncs an individual member's task completion state back to the group assignment
  Future<void> syncTaskCompletion(TaskModel task) async {
    final groupId = task.assignedByGroupId;
    final assignmentId = task.groupAssignmentId;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (groupId == null || assignmentId == null || uid == null) return;
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final completionRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('completions')
          .doc(uid);

      await completionRef.set({
        'status': task.done ? 'done' : 'pending',
        'completedAt': task.done ? Timestamp.now() : null,
        'currentCount': task.done ? (task.targetCount ?? 1) : 0,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing task completion back to group: $e');
    }
  }

  /// Syncs an individual member's habit completion / count progress back to the group assignment
  Future<void> syncHabitCompletion(HabitModel habit) async {
    final groupId = habit.assignedByGroupId;
    final assignmentId = habit.groupAssignmentId;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (groupId == null || assignmentId == null || uid == null) return;
    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final completionRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('assignments')
          .doc(assignmentId)
          .collection('completions')
          .doc(uid);

      final isDone = habit.isCompleted ||
          (habit.targetCount != null && habit.currentCount >= habit.targetCount!) ||
          (habit.completionMode != 'count' && habit.completedThisWeekCount > 0);

      await completionRef.set({
        'status': isDone ? 'done' : 'pending',
        'completedAt': isDone ? Timestamp.now() : null,
        'currentCount': habit.currentCount,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing habit completion back to group: $e');
    }
  }
}
