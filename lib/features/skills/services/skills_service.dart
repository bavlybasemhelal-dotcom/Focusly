import '../../../core/data/completion_ledger.dart';
import '../../../core/data/pending_operations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
    return _skillsCollection(
      uid,
    ).orderBy('level', descending: true).snapshots().map((snapshot) {
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
      if (levelInput < 1 ||
          levelInput > 999 ||
          xpInput < 0 ||
          xpInput > 100000) {
        throw ArgumentError('Invalid skill progress');
      }
      final now = DateTime.now();
      final target = _skillsCollection(uid).doc(skill.id);
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(target);
        if (!snapshot.exists || snapshot.data()?['deletionPending'] == true) {
          throw StateError('Skill no longer exists');
        }
        final current = SkillModel.fromMap(snapshot.data()!, snapshot.id);
        final progressChanged =
            levelInput != skill.level || xpInput != skill.xp;
        if (progressChanged &&
            (current.level != skill.level || current.xp != skill.xp)) {
          throw StateError(
            'Skill progress changed. Reload before replacing it.',
          );
        }
        final norm = SkillMathHelper.normalizeDirectInput(
          levelInput: progressChanged ? levelInput : current.level,
          xpInput: progressChanged ? xpInput : current.xp,
          previousLevel: current.level,
        );
        tx.update(target, {
          'level': norm.newLevel,
          'xp': norm.newXp,
          if (name != null && name.trim() != skill.name) 'name': name.trim(),
          if (category != null && category.trim() != skill.category)
            'category': category.trim(),
          if (color != null && color != skill.color) 'color': color,
          'history': SkillMathHelper.updateHistoryToday(
            current.history,
            norm.newLevel,
          ),
          'updatedAt': Timestamp.fromDate(now),
        });
        tx.set(
          target.collection('dailyProgress').doc(CompletionLedger.dateKey(now)),
          {
            'date': CompletionLedger.dateKey(now),
            'level': norm.newLevel,
            'xp': norm.newXp,
            'totalXp': (norm.newLevel - 1) * 100 + norm.newXp,
            'source': progressChanged ? 'manual' : 'metadata',
            'updatedAt': Timestamp.fromDate(now),
          },
        );
      });
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
      final target = _skillsCollection(uid).doc(skillId);
      await target.update({'deletionPending': true});
      for (final collection in ['taskClaims', 'dailyProgress']) {
        while (true) {
          final page = await target.collection(collection).limit(150).get();
          if (page.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final doc in page.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }
      await target.delete();
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
    bool throwOnFailure = false,
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
      if (snapshot.docs.isEmpty) { await PendingOperations.acknowledge(uid,'skill',task.id); return; }

      final allSkills = snapshot.docs
          .map((doc) => SkillModel.fromMap(doc.data(), doc.id))
          .toList();

      List<SkillModel> targetSkills = [];

      // 1. Explicit skillId check
      if (task.skillId != null && task.skillId!.isNotEmpty) {
        targetSkills = allSkills.where((s) => s.id == task.skillId).toList();
      }

      // 2. Category matching fallback
      if (targetSkills.isEmpty &&
          (task.skillId == null || task.skillId!.isEmpty)) {
        targetSkills = allSkills
            .where((s) => s.category == task.categoryId)
            .toList();
      }

      if (targetSkills.isEmpty) { await PendingOperations.acknowledge(uid,'skill',task.id); return; }

      final List<SkillModel> leveledUpSkills = [];
      for (final skill in targetSkills) {
        final docRef = _skillsCollection(uid).doc(skill.id);
        final claim = docRef.collection('taskClaims').doc(task.id);
        final changed = await _firestore.runTransaction<SkillModel?>((
          transaction,
        ) async {
          final previousClaim = await transaction.get(claim);
          final previous = await transaction.get(docRef);
          if (previousClaim.exists ||
              !previous.exists ||
              previous.data()?['deletionPending'] == true) {
            return null;
          }
          final current = SkillModel.fromMap(previous.data()!, skill.id);
          final result = SkillMathHelper.computeXpProgress(
            currentLevel: current.level,
            currentXp: current.xp,
            addedXp: xpToAward,
          );
          final history = SkillMathHelper.updateHistoryToday(
            current.history,
            result.newLevel,
          );
          final now = DateTime.now();
          transaction.set(claim, {
            'taskId': task.id,
            'amount': xpToAward,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(docRef, {
            'level': result.newLevel,
            'xp': result.newXp,
            'history': history,
            'updatedAt': Timestamp.fromDate(now),
          });
          transaction.set(
            docRef
                .collection('dailyProgress')
                .doc(CompletionLedger.dateKey(now)),
            {
              'date': CompletionLedger.dateKey(now),
              'level': result.newLevel,
              'xp': result.newXp,
              'totalXp': (result.newLevel - 1) * 100 + result.newXp,
            },
          );
          return result.didLevelUp
              ? current.copyWith(level: result.newLevel, xp: result.newXp)
              : null;
        });
        if (changed != null) leveledUpSkills.add(changed);
      }

      // Show celebratory toasts and group feed hooks on level-up
      await PendingOperations.acknowledge(uid,'skill',task.id);
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
          uid: uid,
          type: 'level_up',
          message: 'Leveled up skill "${s.name}" to Level ${s.level}! ⚡🎯',
          icon: '🎯',
        );
      }
    } catch (e) {
      debugPrint('Error awarding skill XP from task completion: $e');
      if (throwOnFailure) rethrow;
    }
  }
}
