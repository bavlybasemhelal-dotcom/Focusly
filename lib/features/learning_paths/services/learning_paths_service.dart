import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../progress/services/progress_service.dart';
import '../helpers/learning_path_helpers.dart';
import '../models/learning_path_model.dart';

/// Service managing Firestore operations for the Learning Paths feature.
///
/// Documents are isolated per user under `users/{uid}/learningPaths/{pathId}`.
class LearningPathsService {
  final FirebaseFirestore _firestore;

  LearningPathsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _pathsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('learningPaths');
  }

  /// Streams all learning paths for [uid] ordered by updatedAt descending.
  Stream<List<LearningPathModel>> streamPaths(String uid) {
    return _pathsCollection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LearningPathModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new learning path.
  Future<String?> addPath({
    required String uid,
    required String title,
    int totalDays = 30,
    List<PathStepModel>? initialSteps,
  }) async {
    try {
      final docRef = _pathsCollection(uid).doc();
      final now = DateTime.now();

      final steps = LearningPathHelpers.resizeSteps(
        initialSteps ?? const [],
        totalDays,
      );

      final progress = steps.where((s) => s.completed).length;

      final path = LearningPathModel(
        id: docRef.id,
        title: title.trim(),
        totalDays: totalDays,
        steps: steps,
        progressDay: progress,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(path.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding learning path: $e');
      return null;
    }
  }

  /// Updates an existing learning path (including resizing steps if totalDays changed).
  Future<bool> updatePath({
    required String uid,
    required LearningPathModel currentPath,
    required String newTitle,
    required int newTotalDays,
    List<PathStepModel>? updatedSteps,
  }) async {
    try {
      final now = DateTime.now();
      final baseSteps = updatedSteps ?? currentPath.steps;

      final resizedSteps = LearningPathHelpers.resizeSteps(
        baseSteps,
        newTotalDays,
      );

      final updatedPath = LearningPathHelpers.syncPathProgress(
        currentPath.copyWith(
          title: newTitle.trim(),
          totalDays: newTotalDays,
          steps: resizedSteps,
          updatedAt: now,
        ),
      );

      await _pathsCollection(uid).doc(updatedPath.id).update(updatedPath.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating learning path: $e');
      return false;
    }
  }

  /// Deletes a learning path.
  Future<bool> deletePath({
    required String uid,
    required String pathId,
  }) async {
    try {
      await _pathsCollection(uid).doc(pathId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting learning path: $e');
      return false;
    }
  }

  /// Toggles a day step's manual completion (used when day has no sub-steps).
  Future<bool> toggleStepCompletion({
    required String uid,
    required LearningPathModel path,
    required int day,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final wasCompleted = step.completed;
      final newCompleted = !wasCompleted;

      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = step.copyWith(completed: newCompleted);

      final updatedPath = LearningPathHelpers.syncPathProgress(
        path.copyWith(steps: updatedSteps, updatedAt: DateTime.now()),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());

      // XP hook & celebration on day completion
      if (!wasCompleted && newCompleted) {
        _triggerDayCompletionCelebration(day, context, ref);
      }

      return true;
    } catch (e) {
      debugPrint('Error toggling step completion: $e');
      return false;
    }
  }

  /// Toggles a specific sub-step's completion checkbox and updates day completion.
  Future<bool> toggleSubStepCompletion({
    required String uid,
    required LearningPathModel path,
    required int day,
    required String subStepId,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final wasDayCompleted = step.completed;

      final updatedSubSteps = step.subSteps.map((sub) {
        if (sub.id == subStepId) {
          return sub.copyWith(completed: !sub.completed);
        }
        return sub;
      }).toList();

      final updatedStep = step.copyWith(
        subSteps: updatedSubSteps,
        completed: LearningPathHelpers.evaluateDayCompletion(
          step.copyWith(subSteps: updatedSubSteps),
        ),
      );

      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = updatedStep;

      final updatedPath = LearningPathHelpers.syncPathProgress(
        path.copyWith(steps: updatedSteps, updatedAt: DateTime.now()),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());

      // XP hook: if all sub-steps completed, completing the day
      if (!wasDayCompleted && updatedStep.completed) {
        _triggerDayCompletionCelebration(day, context, ref);
      }

      return true;
    } catch (e) {
      debugPrint('Error toggling sub-step completion: $e');
      return false;
    }
  }

  /// Adds a new sub-step item to a day's checklist.
  Future<bool> addSubStep({
    required String uid,
    required LearningPathModel path,
    required int day,
    required String subStepTitle,
  }) async {
    if (subStepTitle.trim().isEmpty) return false;
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final newSub = PathSubStepModel(
        id: UniqueKey().toString(),
        title: subStepTitle.trim(),
        completed: false,
      );

      final updatedSubSteps = [...step.subSteps, newSub];
      final isDayComplete = LearningPathHelpers.evaluateDayCompletion(
        step.copyWith(subSteps: updatedSubSteps),
      );

      final updatedStep = step.copyWith(
        subSteps: updatedSubSteps,
        completed: isDayComplete,
      );

      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = updatedStep;

      final updatedPath = LearningPathHelpers.syncPathProgress(
        path.copyWith(steps: updatedSteps, updatedAt: DateTime.now()),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());
      return true;
    } catch (e) {
      debugPrint('Error adding sub-step: $e');
      return false;
    }
  }

  /// Deletes a sub-step from a day's checklist.
  Future<bool> deleteSubStep({
    required String uid,
    required LearningPathModel path,
    required int day,
    required String subStepId,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final wasDayCompleted = step.completed;

      final updatedSubSteps = step.subSteps.where((s) => s.id != subStepId).toList();
      final isDayComplete = LearningPathHelpers.evaluateDayCompletion(
        step.copyWith(subSteps: updatedSubSteps),
      );

      final updatedStep = step.copyWith(
        subSteps: updatedSubSteps,
        completed: isDayComplete,
      );

      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = updatedStep;

      final updatedPath = LearningPathHelpers.syncPathProgress(
        path.copyWith(steps: updatedSteps, updatedAt: DateTime.now()),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());

      // If deleting an incomplete sub-step made all remaining sub-steps complete:
      if (!wasDayCompleted && updatedStep.completed && updatedSubSteps.isNotEmpty) {
        _triggerDayCompletionCelebration(day, context, ref);
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting sub-step: $e');
      return false;
    }
  }

  /// Updates a day's topic title.
  Future<bool> updateDayTitle({
    required String uid,
    required LearningPathModel path,
    required int day,
    required String newTitle,
  }) async {
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final updatedStep = step.copyWith(title: newTitle.trim());

      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = updatedStep;

      final updatedPath = path.copyWith(
        steps: updatedSteps,
        updatedAt: DateTime.now(),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating day title: $e');
      return false;
    }
  }

  /// Manual override to mark a day complete/incomplete.
  Future<bool> manualDayOverride({
    required String uid,
    required LearningPathModel path,
    required int day,
    required bool completed,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final stepIndex = path.steps.indexWhere((s) => s.day == day);
      if (stepIndex == -1) return false;

      final step = path.steps[stepIndex];
      final wasCompleted = step.completed;

      final updatedStep = step.copyWith(completed: completed);
      final updatedSteps = List<PathStepModel>.from(path.steps);
      updatedSteps[stepIndex] = updatedStep;

      final updatedPath = path.copyWith(
        steps: updatedSteps,
        progressDay: updatedSteps.where((s) => s.completed).length,
        updatedAt: DateTime.now(),
      );

      await _pathsCollection(uid).doc(path.id).update(updatedPath.toMap());

      if (!wasCompleted && completed) {
        _triggerDayCompletionCelebration(day, context, ref);
      }

      return true;
    } catch (e) {
      debugPrint('Error in manual day override: $e');
      return false;
    }
  }

  void _triggerDayCompletionCelebration(
    int day,
    BuildContext? context,
    WidgetRef? ref,
  ) {
    // XP hook: Award +10 XP for completing a curriculum day
    ProgressService().awardXp(10, context: context, ref: ref);

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('day_completed_celebration', args: {'day': day.toString()}),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
  }
}
