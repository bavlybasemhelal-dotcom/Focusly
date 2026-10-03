import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';

/// Service managing Firestore operations for the Life Map (Goals) feature.
///
/// Strictly scoped to `users/{uid}/goals/{goalId}`.
class GoalsService {
  final FirebaseFirestore _firestore;

  GoalsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _goalsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('goals');
  }

  /// Real-time stream of all goals for a given user.
  Stream<List<GoalModel>> streamGoals(String uid) {
    return _goalsCollection(
      uid,
    ).orderBy('createdAt', descending: false).snapshots().map((snap) {
      return snap.docs
          .map((doc) => GoalModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new Goal document in Firestore.
  Future<String?> addGoal({
    required String uid,
    required String title,
    String icon = '🎯',
    String color = '#2563EB',
    String timeframe = '1month',
    String? areaId,
    DateTime? targetDate,
    int progress = 0,
    List<GoalMilestone> milestones = const [],
  }) async {
    try {
      final docRef = _goalsCollection(uid).doc();
      final now = DateTime.now();
      final effectiveProgress = calculateMilestoneProgress(
        milestones,
        progress,
      );

      final goal = GoalModel(
        id: docRef.id,
        title: title.trim(),
        icon: icon.trim().isNotEmpty ? icon.trim() : '🎯',
        color: color.trim().isNotEmpty ? color.trim() : '#2563EB',
        timeframe: timeframe,
        areaId: areaId?.trim().isNotEmpty == true ? areaId!.trim() : null,
        targetDate: targetDate,
        progress: effectiveProgress,
        status: 'active',
        milestones: milestones,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore.runTransaction((tx) async {
        if (goal.areaId != null) {
          final area = await tx.get(
            _firestore
                .collection('users')
                .doc(uid)
                .collection('paraAreas')
                .doc(goal.areaId),
          );
          if (!area.exists || area.data()?['deletionPending'] == true) {
            throw StateError('Area unavailable');
          }
        }
        tx.set(docRef, goal.toMap());
      });
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding goal: $e');
      return null;
    }
  }

  /// Updates an existing goal document.
  Future<bool> updateGoal({
    required String uid,
    required GoalModel goal,
    GoalModel? original,
  }) async {
    try {
      final now = DateTime.now();
      final updated = goal.copyWith(updatedAt: now);
      final target = _goalsCollection(uid).doc(goal.id);
      await _firestore.runTransaction((transaction) async {
        final fresh = await transaction.get(target);
        if (!fresh.exists) throw StateError('Goal no longer exists');
        final patch = updated.toMap()
          ..remove('createdAt')
          ..remove('status');
        if (original != null) {
          final before = original.toMap();
          final fields = patch.keys.toList();
          for (final field in fields) {
            if (field == 'updatedAt') continue;
            if (const DeepCollectionEquality().equals(
              patch[field],
              before[field],
            )) {
              patch.remove(field);
              continue;
            }
            if ((field == 'progress' || field == 'milestones') &&
                !const DeepCollectionEquality().equals(
                  GoalModel.fromMap(fresh.data()!, goal.id).toMap()[field],
                  before[field],
                )) {
              throw StateError('Goal progress changed. Reopen the form.');
            }
          }
        }
        if (patch['areaId'] is String) {
          final area = await transaction.get(
            _firestore
                .collection('users')
                .doc(uid)
                .collection('paraAreas')
                .doc(patch['areaId'] as String),
          );
          if (!area.exists || area.data()?['deletionPending'] == true) {
            throw StateError('Area unavailable');
          }
        }
        transaction.update(target, patch);
      });
      return true;
    } catch (e) {
      debugPrint('Error updating goal: $e');
      return false;
    }
  }

  /// Sets goal status directly ('active' or 'done').
  Future<bool> setGoalStatus({
    required String uid,
    required String goalId,
    required String status,
  }) async {
    if (status != 'active' && status != 'done') return false;
    try {
      final now = DateTime.now();
      await _goalsCollection(uid).doc(goalId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(now),
      });
      return true;
    } catch (e) {
      debugPrint('Error updating goal status: $e');
      return false;
    }
  }

  /// Toggles a milestone done/undone and auto-recalculates progress.
  Future<bool> toggleMilestone({
    required String uid,
    required String goalId,
    required int milestoneIndex,
  }) async {
    try {
      final docRef = _goalsCollection(uid).doc(goalId);
      return _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists || doc.data() == null) return false;
        final goal = GoalModel.fromMap(doc.data()!, doc.id);
        if (milestoneIndex < 0 || milestoneIndex >= goal.milestones.length) {
          return false;
        }
        final milestones = List<GoalMilestone>.from(goal.milestones);
        milestones[milestoneIndex] = milestones[milestoneIndex].copyWith(
          done: !milestones[milestoneIndex].done,
        );
        transaction.update(docRef, {
          'milestones': milestones
              .map((milestone) => milestone.toMap())
              .toList(),
          'progress': calculateMilestoneProgress(milestones),
          'updatedAt': FieldValue.serverTimestamp(),
          'progressSource': 'manual',
          'manualMilestones': FieldValue.arrayUnion([
            milestones[milestoneIndex].title,
          ]),
        });
        transaction.update(docRef, {
          'progressSource': 'manual',
          'manualMilestones': FieldValue.arrayUnion([
            milestones[milestoneIndex].title,
          ]),
        });
        transaction.set(
          _firestore.collection('users').doc(uid).collection('goalAudit').doc(),
          {
            'goalId': goalId,
            'milestoneTitle': milestones[milestoneIndex].title,
            'done': milestones[milestoneIndex].done,
            'source': 'manual',
            'reason': milestones[milestoneIndex].done
                ? 'Manually marked complete'
                : 'Manually marked pending',
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
        return true;
      });
    } catch (e) {
      debugPrint('Error toggling milestone: $e');
      return false;
    }
  }

  Future<void> resumeLinkedMilestone({
    required String uid,
    required String goalId,
    required String title,
  }) async {
    final user = _firestore.collection('users').doc(uid),
        goal = user.collection('goals').doc(goalId);
    await _firestore.runTransaction((tx) async {
      final previous = await tx.get(goal);
      if (!previous.exists || previous.data()?['deletionPending'] == true) {
        throw StateError('Goal no longer exists');
      }
      final data = previous.data()!;
      final links = Map<String, dynamic>.from(data['taskLinks'] as Map? ?? {});
      final ids = links.entries
          .where((entry) => entry.value == title)
          .map((entry) => entry.key)
          .toList();
      if (ids.isEmpty) throw StateError('Link a task to this milestone first');
      var done = true;
      for (final id in ids) {
        final task = await tx.get(user.collection('tasks').doc(id));
        done = done && task.data()?['done'] == true;
      }
      final milestones = List<Map<String, dynamic>>.from(
        (data['milestones'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      );
      for (final milestone in milestones) {
        if (milestone['title'] == title) milestone['done'] = done;
      }
      tx.update(goal, {
        'milestones': milestones,
        'manualMilestones': FieldValue.arrayRemove([title]),
        'progressSource': 'linkedTasks',
        'progress':
            ((milestones.where((value) => value['done'] == true).length /
                        milestones.length) *
                    100)
                .round(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(user.collection('goalAudit').doc(), {
        'goalId': goalId,
        'milestoneTitle': title,
        'source': 'linkedTasks',
        'reason': 'Resumed progress from linked tasks',
        'done': done,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Deletes a goal document.
  Future<bool> deleteGoal({required String uid, required String goalId}) async {
    try {
      final target = _goalsCollection(uid).doc(goalId);
      await target.update({'deletionPending': true});
      while (true) {
        final page = await _firestore
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .where('goalId', isEqualTo: goalId)
            .limit(100)
            .get();
        if (page.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final task in page.docs) {
          batch.update(task.reference, {
            'goalId': null,
            'milestoneTitle': null,
          });
        }
        await batch.commit();
      }
      await target.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      return false;
    }
  }
}
