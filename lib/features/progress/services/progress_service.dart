import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../habits/providers/habits_provider.dart';
import '../../pomodoro/providers/pomodoro_provider.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/achievement_model.dart';
import '../models/achievements_data.dart';
import '../models/level_logic.dart';
import '../providers/progress_provider.dart';
import '../../groups/services/challenge_service.dart';
import '../../groups/services/group_feed_service.dart';
import '../../focus_mode/providers/focus_mode_provider.dart';
import '../../focus_mode/services/notification_queue.dart';

/// Shared service for XP awards, level progression, and achievement verification.
///
/// Easily called by Tasks, Habits, Pomodoro, and Schedule features.
class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  DocumentReference<Map<String, dynamic>>? get _progressDoc {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    if (uid == null || uid.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('stats')
        .doc('progress');
  }

  /// Awards XP to the current user and triggers achievement checks
  Future<void> awardXp(int amount, {BuildContext? context, WidgetRef? ref}) async {
    if (amount <= 0) return;

    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    try {
      final doc = _progressDoc;
      if (doc != null) {
        await doc.set(
          {
            'xp': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // Group weeklyXP update & Challenge progress sync
      if (uid != null && uid.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final groupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);
        if (groupIds.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final gId in groupIds) {
            final memberRef = FirebaseFirestore.instance
                .collection('groups')
                .doc(gId)
                .collection('members')
                .doc(uid);
            batch.update(memberRef, {'weeklyXP': FieldValue.increment(amount)});
          }
          await batch.commit();
        }
      }

      ChallengeService().triggerProgressSync();
    } catch (_) {}

    if (context != null && ref != null && context.mounted) {
      checkAndUnlockAchievements(context, ref);
    }
  }

  /// Evaluates all achievements against user data and unlocks new badges
  Future<void> checkAndUnlockAchievements(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final tasks = ref.read(tasksStreamProvider).value ?? [];
      final habits = ref.read(habitsStreamProvider).value ?? [];
      final pomodoroLogs = ref.read(pomodoroLogsStreamProvider).value ?? [];
      final events = ref.read(eventsStreamProvider).value ?? [];
      final categories = ref.read(categoriesProvider).value ?? [];
      final totalXp = ref.read(userXpStreamProvider).value ?? 0;
      final levelInfo = LevelLogic.calculate(totalXp);

      final unlockedMap =
          ref.read(unlockedAchievementsStreamProvider).value ?? {};

      final ctx = AchievementContext(
        tasks: tasks,
        habits: habits,
        pomodoroLogs: pomodoroLogs,
        events: events,
        categories: categories,
        totalXp: totalXp,
        level: levelInfo.level,
      );

      final List<AchievementModel> newlyUnlocked = [];

      for (final achievement in AchievementsData.allAchievements) {
        if (!unlockedMap.containsKey(achievement.id)) {
          if (achievement.isUnlocked(ctx)) {
            newlyUnlocked.add(achievement);
          }
        }
      }

      if (newlyUnlocked.isEmpty) return;

      final doc = _progressDoc;
      if (doc != null) {
        final Map<String, dynamic> updates = {};
        for (final item in newlyUnlocked) {
          updates['unlockedAchievements.${item.id}'] =
              Timestamp.fromDate(DateTime.now());
        }

        await doc.set(updates, SetOptions(merge: true));
      }

      // Show or queue celebratory notifications for each new achievement
      if (context.mounted) {
        final isFocusActive = ref.read(focusModeActiveProvider);

        for (final achievement in newlyUnlocked) {
          if (isFocusActive) {
            // Queue celebratory notification until Focus Mode exits
            NotificationQueue().queueCelebration((ctx) {
              if (ctx.mounted) {
                _showAchievementCelebration(ctx, achievement);
              }
            });
          } else {
            _showAchievementCelebration(context, achievement);
          }

          // Group feed hook: post achievement to group feeds
          if (achievement.category == AchievementCategory.levels) {
            GroupFeedService().pushToAllUserGroups(
              type: 'level_up',
              message: 'Earned achievement: "${context.tr(achievement.titleKey)}" (${achievement.emoji})! 🌟',
              icon: achievement.emoji,
            );
          }
        }
      }
    } catch (_) {}
  }

  void _showAchievementCelebration(
    BuildContext context,
    AchievementModel achievement,
  ) {
    final title = context.tr(achievement.titleKey);
    final desc = context.tr(achievement.descKey);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        backgroundColor: const Color(0xFF0F1B4C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFFF59E0B),
            width: 1.2,
          ),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                achievement.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏆 ${context.tr('achievement_unlocked_title')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
