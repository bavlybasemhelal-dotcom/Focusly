import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../progress/constants/xp_constants.dart';
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

  /// Merge changes to independent days; reject edits to a day changed elsewhere.
  Future<void> _saveProgress(
    String uid,
    LearningPathModel before,
    LearningPathModel after,
  ) async {
    final document = _pathsCollection(uid).doc(before.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      if (!snapshot.exists) throw StateError('Learning path no longer exists');
      final fresh = LearningPathModel.fromMap(snapshot.data()!, before.id);
      final changed = <int, PathStepModel>{};
      for (final step in after.steps) {
        final old = before.steps
            .where((item) => item.day == step.day)
            .firstOrNull;
        if (old == null ||
            jsonEncode(old.toMap()) != jsonEncode(step.toMap())) {
          final current = fresh.steps
              .where((item) => item.day == step.day)
              .firstOrNull;
          if (old != null &&
              current != null &&
              jsonEncode(current.toMap()) != jsonEncode(old.toMap())) {
            if (jsonEncode(current.toMap()) == jsonEncode(step.toMap())) {
              continue;
            }
            throw StateError(
              'This day changed on another device. Refresh and retry.',
            );
          }
          changed[step.day] = step;
        }
      }
      final merged = LearningPathHelpers.syncPathProgress(
        fresh.copyWith(
          steps: [for (final step in fresh.steps) changed[step.day] ?? step],
          updatedAt: DateTime.now(),
        ),
      );
      transaction.update(document, {
        'steps': merged.steps.map((step) => step.toMap()).toList(),
        'progressDay': merged.progressDay,
        'updatedAt': Timestamp.fromDate(merged.updatedAt),
      });
    });
  }

  /// Streams all learning paths for [uid] ordered by updatedAt descending.
  Stream<List<LearningPathModel>> streamPaths(String uid) {
    return _pathsCollection(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
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
      if (newTitle.trim().isEmpty || newTotalDays < 1 || newTotalDays > 365) {
        throw ArgumentError('Invalid learning path');
      }
      final target = _pathsCollection(uid).doc(currentPath.id);
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(target);
        if (!snapshot.exists) throw StateError('Path no longer exists');
        final current = LearningPathModel.fromMap(
          snapshot.data()!,
          snapshot.id,
        );
        final proposed = updatedSteps ?? currentPath.steps;
        final merged = LearningPathHelpers.resizeSteps(
          current.steps,
          newTotalDays,
        );
        for (var i = 0; i < proposed.length && i < merged.length; i++) {
          if (i >= currentPath.steps.length ||
              proposed[i].toMap().toString() !=
                  currentPath.steps[i].toMap().toString()) {
            if (i < current.steps.length &&
                i < currentPath.steps.length &&
                current.steps[i].toMap().toString() !=
                    currentPath.steps[i].toMap().toString()) {
              throw StateError(
                'This step changed elsewhere. Reload before editing.',
              );
            }
            merged[i] = proposed[i];
          }
        }
        if (newTotalDays < current.steps.length &&
            current.steps.skip(newTotalDays).any((step) => step.completed)) {
          throw StateError('Cannot remove completed steps');
        }
        tx.update(target, {
          'title': newTitle.trim(),
          'totalDays': newTotalDays,
          'steps': merged.map((step) => step.toMap()).toList(),
          'progressDay': merged.where((step) => step.completed).length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      return true;
    } catch (e) {
      debugPrint('Error updating learning path: $e');
      return false;
    }
  }

  /// Deletes a learning path.
  Future<bool> deletePath({required String uid, required String pathId}) async {
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

      await _saveProgress(uid, path, updatedPath);

      // XP hook & celebration on day completion
      if (!wasCompleted && newCompleted) {
        _triggerDayCompletionCelebration(
          uid,
          path.id,
          day,
          context != null && context.mounted ? context : null,
          ref,
        );
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

      await _saveProgress(uid, path, updatedPath);

      // XP hook: if all sub-steps completed, completing the day
      if (!wasDayCompleted && updatedStep.completed) {
        _triggerDayCompletionCelebration(
          uid,
          path.id,
          day,
          context != null && context.mounted ? context : null,
          ref,
        );
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

      await _saveProgress(uid, path, updatedPath);
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

      final updatedSubSteps = step.subSteps
          .where((s) => s.id != subStepId)
          .toList();
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

      await _saveProgress(uid, path, updatedPath);

      // If deleting an incomplete sub-step made all remaining sub-steps complete:
      if (!wasDayCompleted &&
          updatedStep.completed &&
          updatedSubSteps.isNotEmpty) {
        _triggerDayCompletionCelebration(
          uid,
          path.id,
          day,
          context != null && context.mounted ? context : null,
          ref,
        );
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

      await _saveProgress(uid, path, updatedPath);
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

      await _saveProgress(uid, path, updatedPath);

      if (!wasCompleted && completed) {
        _triggerDayCompletionCelebration(
          uid,
          path.id,
          day,
          context != null && context.mounted ? context : null,
          ref,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error in manual day override: $e');
      return false;
    }
  }

  void _triggerDayCompletionCelebration(
    String uid,
    String pathId,
    int day,
    BuildContext? context,
    WidgetRef? ref,
  ) {
    // XP hook: Award +10 XP for completing a curriculum day
    ProgressService().awardXp(
      XpConstants.learningPathDay,
      source: 'Learning Path day completed: Day $day',
      sourceType: 'learning_path',
      uid: uid,
      sourceId: pathId,
      eventId: 'learning_path_${pathId}_$day',
      context: context,
      ref: ref,
    );

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'day_completed_celebration',
              args: {'day': day.toString()},
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }
  }
}
