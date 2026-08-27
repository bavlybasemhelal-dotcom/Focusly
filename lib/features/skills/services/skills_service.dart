import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../groups/services/group_feed_service.dart';
import '../../progress/constants/xp_constants.dart';
import '../../tasks/models/task_model.dart';
import '../helpers/skill_math_helper.dart';
import '../models/skill_model.dart';

/// Service managing Firestore operations for the Skills Board feature.
///
/// Documents are isolated per user under `users/{uid}/skills/{skillId}`.
class SkillsService {
  final FirebaseFirestore _firestore;

  SkillsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _skillsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('skills');
  }

  /// Streams all skills for [uid] ordered by level descending, then xp descending.
  Stream<List<SkillModel>> streamSkills(String uid) {
    return _skillsCollection(uid)
        .orderBy('level', descending: true)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => SkillModel.fromMap(doc.data(), doc.id))
          .toList();
      // Secondary in-memory sort by XP descending
      list.sort((a, b) {
        final levelCmp = b.level.compareTo(a.level);
        if (levelCmp != 0) return levelCmp;
        return b.xp.compareTo(a.xp);
      });
      return list;
    });
  }

  /// Adds a new skill with initialized 7-day history snapshots.
  Future<String?> addSkill({
    required String uid,
    required String name,
    required String category,
    int level = 1,
    int xp = 0,
    int color = 0xFF2E6FF2,
  }) async {
    try {
      final docRef = _skillsCollection(uid).doc();
      final now = DateTime.now();

      // Normalize direct level/XP inputs (handles overflow e.g. XP >= 100)
      final norm = SkillMathHelper.normalizeDirectInput(
        levelInput: level,
        xpInput: xp,
      );

      final skill = SkillModel(
        id: docRef.id,
        name: name.trim(),
        category: category.trim(),
        level: norm.newLevel,
        xp: norm.newXp,
        color: color,
        history: List<int>.filled(7, norm.newLevel),
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(skill.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding skill: $e');
      return null;
    }
  }

  /// Updates an existing skill with direct level/XP changes and updates today's snapshot.
  Future<bool> updateSkill({
    required String uid,
    required SkillModel skill,
    required int levelInput,
    required int xpInput,
    String? name,
    String? category,
    int? color,
  }) async {
    try {
      final now = DateTime.now();

      // Calculate normalized level and remaining XP
      final norm = SkillMathHelper.normalizeDirectInput(
        levelInput: levelInput,
        xpInput: xpInput,
        previousLevel: skill.level,
      );

      final updatedHistory = SkillMathHelper.updateHistoryToday(
        skill.history,
        norm.newLevel,
      );

      final updated = skill.copyWith(
        name: name?.trim() ?? skill.name,
        category: category?.trim() ?? skill.category,
        level: norm.newLevel,
        xp: norm.newXp,
        color: color ?? skill.color,
        history: updatedHistory,
        updatedAt: now,
      );

      await _skillsCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating skill: $e');
      return false;
    }
  }

  /// Deletes a specific skill.
  Future<bool> deleteSkill({
    required String uid,
    required String skillId,
  }) async {
    try {
      await _skillsCollection(uid).doc(skillId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting skill: $e');
      return false;
    }
  }

  /// Automatic XP hook for Task completions.
  ///
  /// Priority XP Tiers:
  /// - High: +25 XP
  /// - Medium: +15 XP
  /// - Low: +10 XP
  ///
  /// Target rule:
  /// - If task has explicit [task.skillId], award to that skill only.
  /// - Otherwise, award to all skills matching [task.categoryId].
  Future<void> awardTaskCompletionXp({
    required String uid,
    required TaskModel task,
    BuildContext? context,
  }) async {
    try {
      int xpToAward;
      switch (task.priority) {
        case TaskPriority.high:
          xpToAward = XpConstants.taskSkillHigh;
          break;
        case TaskPriority.medium:
          xpToAward = XpConstants.taskSkillMedium;
          break;
        case TaskPriority.low:
          xpToAward = XpConstants.taskSkillLow;
          break;
      }

      final snapshot = await _skillsCollection(uid).get();
      if (snapshot.docs.isEmpty) return;

      final allSkills = snapshot.docs
          .map((doc) => SkillModel.fromMap(doc.data(), doc.id))
          .toList();

      List<SkillModel> targetSkills = [];

      // 1. Explicit skillId check
      if (task.skillId != null && task.skillId!.isNotEmpty) {
        targetSkills = allSkills.where((s) => s.id == task.skillId).toList();
      }

      // 2. Category matching fallback
      if (targetSkills.isEmpty) {
        targetSkills = allSkills.where((s) => s.category == task.categoryId).toList();
      }

      if (targetSkills.isEmpty) return;

      final now = DateTime.now();
      final batch = _firestore.batch();
      final List<SkillModel> leveledUpSkills = [];

      for (final skill in targetSkills) {
        final result = SkillMathHelper.computeXpProgress(
          currentLevel: skill.level,
          currentXp: skill.xp,
          addedXp: xpToAward,
        );

        final updatedHistory = SkillMathHelper.updateHistoryToday(
          skill.history,
          result.newLevel,
        );

        final updatedSkill = skill.copyWith(
          level: result.newLevel,
          xp: result.newXp,
          history: updatedHistory,
          updatedAt: now,
        );

        final docRef = _skillsCollection(uid).doc(skill.id);
        batch.update(docRef, updatedSkill.toMap());

        if (result.didLevelUp) {
          leveledUpSkills.add(updatedSkill);
        }
      }

      await batch.commit();

      // Show celebratory toasts and group feed hooks on level-up
      for (final s in leveledUpSkills) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  'skill_level_up_toast',
                  args: {'level': s.level.toString(), 'skillName': s.name},
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

        GroupFeedService().pushToAllUserGroups(
          type: 'level_up',
          message: 'Leveled up skill "${s.name}" to Level ${s.level}! ⚡🎯',
          icon: '🎯',
        );
      }
    } catch (e) {
      debugPrint('Error awarding skill XP from task completion: $e');
    }
  }
}
