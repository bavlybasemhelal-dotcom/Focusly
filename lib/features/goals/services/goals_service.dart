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
    return _goalsCollection(uid)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
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
      final effectiveProgress = calculateMilestoneProgress(milestones, progress);

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

      await docRef.set(goal.toMap());
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
  }) async {
    try {
      final now = DateTime.now();
      final updated = goal.copyWith(updatedAt: now);
      await _goalsCollection(uid).doc(goal.id).set(
            updated.toMap(),
            SetOptions(merge: true),
          );
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
    try {
      final now = DateTime.now();
      await _goalsCollection(uid).doc(goalId).set(
        {
          'status': status,
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
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
      final doc = await docRef.get();
      if (!doc.exists || doc.data() == null) return false;

      final goal = GoalModel.fromMap(doc.data()!, doc.id);
      if (milestoneIndex < 0 || milestoneIndex >= goal.milestones.length) return false;

      final target = goal.milestones[milestoneIndex];
      final updatedMilestones = List<GoalMilestone>.from(goal.milestones);
      updatedMilestones[milestoneIndex] = target.copyWith(done: !target.done);

      final newProgress = calculateMilestoneProgress(updatedMilestones);
      final now = DateTime.now();

      await docRef.set(
        {
          'milestones': updatedMilestones.map((m) => m.toMap()).toList(),
          'progress': newProgress,
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );

      return true;
    } catch (e) {
      debugPrint('Error toggling milestone: $e');
      return false;
    }
  }

  /// Deletes a goal document.
  Future<bool> deleteGoal({
    required String uid,
    required String goalId,
  }) async {
    try {
      await _goalsCollection(uid).doc(goalId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      return false;
    }
  }
}
