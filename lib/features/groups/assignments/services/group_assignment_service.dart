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
  static final GroupAssignmentService _instance =
      GroupAssignmentService._internal();
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
    String? requestId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) throw StateError('Firebase is unavailable');

    final currentUser = FirebaseAuth.instance.currentUser;
    final adminUid = currentUser?.uid ?? '';
    final adminName = (currentUser?.displayName?.trim().isNotEmpty == true)
        ? currentUser!.displayName!
        : 'Admin';

    if (adminUid.isEmpty ||
        !['task', 'habit'].contains(type) ||
        title.trim().isEmpty ||
        !['simple', 'count'].contains(completionMode) ||
        selectedMembers.isEmpty ||
        selectedMembers.length > 20 ||
        selectedMembers.map((m) => m.uid).toSet().length !=
            selectedMembers.length ||
        (completionMode == 'count' &&
            (targetCount == null || targetCount < 1 || targetCount > 10000))) {
      throw ArgumentError('Invalid assignment');
    }
    final now = DateTime.now();
    final groupRef = firestore.collection('groups').doc(groupId);
    final assignmentRef = groupRef.collection('assignments').doc(requestId);
    final assignmentId = assignmentRef.id;

    final assignedUids = selectedMembers.map((m) => m.uid).toList();

    var assignment = GroupAssignmentModel(
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
      await firestore.runTransaction((transaction) async {
        final previous = await transaction.get(assignmentRef);
        if (previous.exists) {
          assignment = GroupAssignmentModel.fromMap(
            previous.data()!,
            previous.id,
          );
        } else {
          transaction.set(assignmentRef, {
            ...assignment.toMap(),
            'distributionPending': true,
          });
        }
      });

      // 2. Create Completion Tracker Document + Personal Task/Habit for each assigned member
      // Each recipient is atomic. Deterministic IDs make interrupted distribution resumable.
      final chosen = {for (final member in selectedMembers) member.uid: member};
      for (final recipient in assignment.assignedTo) {
        final membership = await groupRef
            .collection('members')
            .doc(recipient)
            .get();
        if (membership.data()?['status'] != 'approved') continue;
        final member =
            chosen[recipient] ??
            GroupMemberModel.fromMap(membership.data()!, recipient);
        final existing = await assignmentRef
            .collection('completions')
            .doc(member.uid)
            .get();
        if (existing.exists) continue;
        final batch = firestore.batch();
        final itemId = 'assignment_$assignmentId';
        final completionRef = assignmentRef
            .collection('completions')
            .doc(member.uid);
        final completionDoc = AssignmentCompletionModel(
          uid: member.uid,
          memberName: member.name,
          status: 'pending',
          currentCount: 0,
          completedAt: null,
        );
        batch.set(completionRef, {
          ...completionDoc.toMap(),
          'itemId': itemId,
          'decision': 'offered',
        });

        if (assignment.type == 'task') {
          // Write locked task to member's personal collection
          final memberTaskRef = firestore
              .collection('users')
              .doc(member.uid)
              .collection('tasks')
              .doc(itemId);

          final memberTask = TaskModel(
            id: memberTaskRef.id,
            title: assignment.title,
            categoryId: 'work',
            priority: TaskPriority.medium,
            date: assignment.deadline ?? now,
            deadline: assignment.deadline,
            done: false,
            createdAt: now,
            groupAssignmentId: assignmentId,
            assignedByGroupId: groupId,
            assignedByName: adminName,
            locked: true,
            completionMode: assignment.completionMode,
            targetCount: assignment.completionMode == 'count'
                ? assignment.targetCount
                : null,
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
              .doc(itemId);

          final memberHabit = HabitModel(
            deadline: assignment.deadline,
            id: memberHabitRef.id,
            title: assignment.title,
            days: List<bool>.filled(7, false),
            streak: 0,
            baseStreak: 0,
            resetDay: DateTime.saturday,
            autoReset: assignment.completionMode != 'count',
            lastResetDate: now,
            createdAt: now,
            groupAssignmentId: assignmentId,
            assignedByGroupId: groupId,
            assignedByName: adminName,
            locked: true,
            completionMode: assignment.completionMode,
            targetCount: assignment.completionMode == 'count'
                ? assignment.targetCount
                : null,
            currentCount: 0,
            isCompleted: false,
          );

          batch.set(memberHabitRef, memberHabit.toMap());
        }
        await batch.commit();
      }
      await assignmentRef.update({'distributionPending': false});

      // 3. Post Announcement Feed Entry to the Group
      final memberCountText = selectedMembers.length == 1
          ? '1 member'
          : '${selectedMembers.length} members';

      await GroupFeedService().postToGroup(
        groupId: groupId,
        uid: adminUid,
        type: 'assignment',
        message: '$adminName assigned "$title" to $memberCountText 📋',
        icon: '📋',
        eventId: 'assignment_${assignmentRef.id}',
      );
    } catch (e) {
      debugPrint('Error creating group assignment: $e');
      rethrow;
    }
  }

  /// Syncs an individual member's task completion state back to the group assignment
  Future<void> syncTaskCompletion(TaskModel task, {String? uid}) async {
    final groupId = task.assignedByGroupId;
    final assignmentId = task.groupAssignmentId;
    uid ??= FirebaseAuth.instance.currentUser?.uid;

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
        'currentCount': task.completionMode == 'count'
            ? task.currentCount
            : (task.done ? 1 : 0),
        'uid': uid,
        'itemId': task.id,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing task completion back to group: $e');
      rethrow;
    }
  }

  /// Syncs an individual member's habit completion / count progress back to the group assignment
  Future<void> syncHabitCompletion(HabitModel habit, {String? uid}) async {
    final groupId = habit.assignedByGroupId;
    final assignmentId = habit.groupAssignmentId;
    uid ??= FirebaseAuth.instance.currentUser?.uid;

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

      final isDone =
          habit.isCompleted ||
          (habit.targetCount != null &&
              habit.currentCount >= habit.targetCount!) ||
          (habit.completionMode != 'count' && habit.isCompleted);

      await completionRef.set({
        'status': isDone ? 'done' : 'pending',
        'completedAt': isDone ? Timestamp.now() : null,
        'currentCount': habit.completionMode == 'count'
            ? habit.currentCount
            : (isDone ? 1 : 0),
        'uid': uid,
        'itemId': habit.id,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing habit completion back to group: $e');
      rethrow;
    }
  }
}
