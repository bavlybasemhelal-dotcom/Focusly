import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../habits/models/habit_model.dart';
import '../../habits/providers/habits_provider.dart';
import '../../pomodoro/models/pomodoro_log_model.dart';
import '../../pomodoro/providers/pomodoro_provider.dart';
import '../../schedule/models/event_model.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../tasks/models/category_model.dart';
import '../../tasks/models/task_model.dart';
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

  /// Awards XP to the current user, writes to the transparent xpLog history,
  /// and triggers achievement checks.
  Future<void> awardXp(
    int amount, {
    String? source,
    String? sourceType,
    BuildContext? context,
    WidgetRef? ref,
    Ref? containerRef,
    String? uid,
  }) async {
    String? effectiveUid = uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (amount > 0 && effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        final progressDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(effectiveUid)
            .collection('stats')
            .doc('progress');

        // Check previous level for level-up celebration
        final prevSnap = await progressDocRef.get();
        final prevXp = (prevSnap.data()?['xp'] as int?) ?? 0;
        final prevLevel = LevelLogic.calculate(prevXp).level;
        final newLevel = LevelLogic.calculate(prevXp + amount).level;

        // 1. Increment User XP in stats/progress
        await progressDocRef.set(
          {
            'xp': FieldValue.increment(amount),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 2. Write transparent XP audit log entry
        final logDocRef = FirebaseFirestore.instance
            .collection('users')
            .doc(effectiveUid)
            .collection('xpLog')
            .doc();

        final label = source ?? 'Productivity action';
        await logDocRef.set({
          'amount': amount,
          'source': label,
          'sourceType': sourceType,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Group weeklyXP update & Challenge progress sync
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(effectiveUid)
            .get();
        final groupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);
        if (groupIds.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (final gId in groupIds) {
            final memberRef = FirebaseFirestore.instance
                .collection('groups')
                .doc(gId)
                .collection('members')
                .doc(effectiveUid);
            batch.update(memberRef, {'weeklyXP': FieldValue.increment(amount)});
          }
          await batch.commit();
        }

        ChallengeService().triggerProgressSync();

        // 4. Level-up celebration with source attribution
        if (newLevel > prevLevel && context != null && context.mounted) {
          final levelInfo = LevelLogic.calculate(prevXp + amount);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Text(levelInfo.emoji, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('level')} $newLevel: ${context.tr(levelInfo.titleKey)}! 🎉',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF2563EB),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error in awardXp Firestore write: $e');
      }
    }

    // Always run achievement check and unlock routine
    await checkAndUnlockAchievements(
      context: context,
      widgetRef: ref,
      ref: containerRef,
      uid: effectiveUid,
    );
  }

  /// Evaluates all achievements against current user data and unlocks new badges in Firestore.
  ///
  /// ROOT CAUSE & ARCHITECTURAL NOTE:
  /// Previously:
  /// 1. `checkAndUnlockAchievements` was only called if both `context` and `ref` were non-null,
  ///    causing Task, Habit, and Pomodoro hooks without `context`/`ref` to never evaluate.
  /// 2. `awardXp(0)` exited immediately at `amount <= 0`, ignoring zero-XP achievement hooks.
  /// 3. Firestore write used dot-notation `unlockedAchievements.${id}` inside `doc.set(..., merge: true)`,
  ///    which created a top-level string key with a dot instead of a nested map field.
  ///
  /// We now:
  /// - Accept optional context/ref/uid and fallback to live Firestore queries when streams are not yet populated.
  /// - Save nested maps directly to `unlockedAchievements` with `SetOptions(merge: true)`.
  /// - Show celebrations if a valid mounted BuildContext is available.
  Future<List<AchievementModel>> checkAndUnlockAchievements({
    BuildContext? context,
    WidgetRef? widgetRef,
    Ref? ref,
    String? uid,
  }) async {
    String? effectiveUid = uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (effectiveUid == null || effectiveUid.isEmpty) return [];

    try {
      List<TaskModel> tasks = [];
      List<HabitModel> habits = [];
      List<PomodoroLogModel> pomodoroLogs = [];
      List<EventModel> events = [];
      List<TaskCategory> categories = [];
      int totalXp = 0;
      Map<String, DateTime> unlockedMap = {};

      // 1. Try reading live provider values if available
      if (ref != null) {
        tasks = ref.read(tasksStreamProvider).value ?? [];
        habits = ref.read(habitsStreamProvider).value ?? [];
        pomodoroLogs = ref.read(pomodoroLogsStreamProvider).value ?? [];
        events = ref.read(eventsStreamProvider).value ?? [];
        categories = ref.read(categoriesProvider).value ?? [];
        totalXp = ref.read(userXpStreamProvider).value ?? 0;
        unlockedMap = ref.read(unlockedAchievementsStreamProvider).value ?? {};
      } else if (widgetRef != null) {
        tasks = widgetRef.read(tasksStreamProvider).value ?? [];
        habits = widgetRef.read(habitsStreamProvider).value ?? [];
        pomodoroLogs = widgetRef.read(pomodoroLogsStreamProvider).value ?? [];
        events = widgetRef.read(eventsStreamProvider).value ?? [];
        categories = widgetRef.read(categoriesProvider).value ?? [];
        totalXp = widgetRef.read(userXpStreamProvider).value ?? 0;
        unlockedMap = widgetRef.read(unlockedAchievementsStreamProvider).value ?? {};
      }

      // 2. If provider data is empty or no ref provided, fetch from Firestore directly
      if (tasks.isEmpty ||
          habits.isEmpty ||
          events.isEmpty ||
          pomodoroLogs.isEmpty ||
          totalXp == 0 ||
          unlockedMap.isEmpty) {
        final firestore = FirebaseFirestore.instance;
        final userDoc = firestore.collection('users').doc(effectiveUid);

        try {
          final results = await Future.wait([
            userDoc.collection('stats').doc('progress').get(),
            userDoc.collection('tasks').get(),
            userDoc.collection('habits').get(),
            userDoc.collection('pomodoroLogs').get(),
            userDoc.collection('events').get(),
            userDoc.collection('categories').get(),
          ]);

          final statsSnap = results[0] as DocumentSnapshot<Map<String, dynamic>>;
          final tasksSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
          final habitsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
          final pomosSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;
          final eventsSnap = results[4] as QuerySnapshot<Map<String, dynamic>>;
          final catsSnap = results[5] as QuerySnapshot<Map<String, dynamic>>;

          if (statsSnap.exists && statsSnap.data() != null) {
            totalXp = statsSnap.data()?['xp'] as int? ?? totalXp;
            final raw = statsSnap.data()?['unlockedAchievements'] as Map<String, dynamic>? ?? {};
            final Map<String, DateTime> directUnlocked = {};
            raw.forEach((k, v) {
              if (v is Timestamp) {
                directUnlocked[k] = v.toDate();
              } else if (v is String) {
                directUnlocked[k] = DateTime.tryParse(v) ?? DateTime.now();
              } else {
                directUnlocked[k] = DateTime.now();
              }
            });
            // Also check top-level keys with prefix
            statsSnap.data()!.forEach((k, v) {
              if (k.startsWith('unlockedAchievements.')) {
                final achId = k.substring('unlockedAchievements.'.length);
                if (!directUnlocked.containsKey(achId)) {
                  if (v is Timestamp) {
                    directUnlocked[achId] = v.toDate();
                  } else {
                    directUnlocked[achId] = DateTime.now();
                  }
                }
              }
            });
            unlockedMap = {...unlockedMap, ...directUnlocked};
          }

          if (tasksSnap.docs.isNotEmpty) {
            tasks = tasksSnap.docs.map((d) => TaskModel.fromMap(d.data(), d.id)).toList();
          }
          if (habitsSnap.docs.isNotEmpty) {
            habits = habitsSnap.docs.map((d) => HabitModel.fromFirestore(d)).toList();
          }
          if (pomosSnap.docs.isNotEmpty) {
            pomodoroLogs = pomosSnap.docs.map((d) => PomodoroLogModel.fromFirestore(d)).toList();
          }
          if (eventsSnap.docs.isNotEmpty) {
            events = eventsSnap.docs.map((d) => EventModel.fromMap(d.data(), d.id)).toList();
          }
          if (catsSnap.docs.isNotEmpty) {
            categories = catsSnap.docs.map((d) => TaskCategory.fromMap(d.data(), d.id)).toList();
          }
        } catch (_) {}
      }

      final levelInfo = LevelLogic.calculate(totalXp);
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

      if (newlyUnlocked.isEmpty) return [];

      // Persist to Firestore: write nested map 'unlockedAchievements'
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(effectiveUid)
          .collection('stats')
          .doc('progress');

      final Map<String, dynamic> achievementUpdates = {};
      final now = DateTime.now();
      for (final item in newlyUnlocked) {
        achievementUpdates[item.id] = Timestamp.fromDate(now);
      }

      await doc.set(
        {
          'unlockedAchievements': achievementUpdates,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Show celebratory notifications for each newly unlocked achievement
      if (context != null && context.mounted) {
        bool isFocusActive = false;
        if (ref != null) {
          isFocusActive = ref.read(focusModeActiveProvider);
        } else if (widgetRef != null) {
          isFocusActive = widgetRef.read(focusModeActiveProvider);
        }

        for (final achievement in newlyUnlocked) {
          if (isFocusActive) {
            NotificationQueue().queueCelebration((c) {
              if (c.mounted) {
                _showAchievementCelebration(c, achievement);
              }
            });
          } else {
            _showAchievementCelebration(context, achievement);
          }

          if (achievement.category == AchievementCategory.levels) {
            GroupFeedService().pushToAllUserGroups(
              type: 'level_up',
              message:
                  'Earned achievement: "${context.tr(achievement.titleKey)}" (${achievement.emoji})! 🌟',
              icon: achievement.emoji,
            );
          }
        }
      }

      return newlyUnlocked;
    } catch (e) {
      debugPrint('Error in checkAndUnlockAchievements: $e');
      return [];
    }
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
