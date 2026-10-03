import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/data/completion_ledger.dart';
import '../../../core/data/firestore_paging.dart';
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
import '../../groups/services/group_feed_service.dart';
import '../../focus_mode/providers/focus_mode_provider.dart';
import '../../focus_mode/services/notification_queue.dart';

/// Shared service for XP awards, level progression, and achievement verification.
///
/// Easily called by Tasks, Habits, Pomodoro, and Schedule features.
class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService({FirebaseFirestore? firestore}) =>
      firestore == null ? _instance : ProgressService._internal(firestore);
  ProgressService._internal([this._injectedFirestore]);
  final FirebaseFirestore? _injectedFirestore;
  FirebaseFirestore get _firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Awards XP to the current user, writes to the transparent xpLog history,
  /// and triggers achievement checks.
  Future<bool> awardXp(
    int amount, {
    String? source,
    String? sourceType,
    BuildContext? context,
    WidgetRef? ref,
    Ref? containerRef,
    String? uid,
    String? eventId,
    String? sourceId,
  }) async {
    String? effectiveUid = uid;
    if (effectiveUid == null || effectiveUid.isEmpty) {
      try {
        effectiveUid = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {}
    }

    if (amount > 0 &&
        (eventId == null || sourceId == null || sourceType == null)) {
      throw ArgumentError('XP awards need a stable event, source and account');
    }
    bool awarded = false;
    if (amount > 0 && effectiveUid != null && effectiveUid.isNotEmpty) {
      try {
        final progressDocRef = _firestore
            .collection('users')
            .doc(effectiveUid)
            .collection('stats')
            .doc('progress');

        // Check previous level for level-up celebration
        final prevSnap = await progressDocRef.get();
        final prevXp = (prevSnap.data()?['xp'] as num?)?.toInt() ?? 0;
        final prevLevel = LevelLogic.calculate(prevXp).level;
        final newLevel = LevelLogic.calculate(prevXp + amount).level;

        final label = source ?? 'Productivity action';
        final ledger = CompletionLedger(_firestore);
        awarded = await ledger.award(
          uid: effectiveUid,
          eventId: eventId!,
          sourceId: sourceId!,
          sourceType: sourceType!,
          amount: amount,
          label: label,
        );
        // Retrying an already committed award also repairs unfinished group copies.
        await ledger.syncGroups(uid: effectiveUid, eventId: eventId);
        if (!awarded) return false;

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error in awardXp Firestore write: $e');
        return false;
      }
    }

    // Always run achievement check and unlock routine
    await checkAndUnlockAchievements(
      context: context != null && context.mounted ? context : null,
      widgetRef: ref,
      ref: containerRef,
      uid: effectiveUid,
    );
    return awarded;
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
        if ([
          ref.read(tasksStreamProvider),
          ref.read(habitsStreamProvider),
          ref.read(pomodoroLogsStreamProvider),
          ref.read(eventsStreamProvider),
          ref.read(categoriesProvider),
          ref.read(userXpStreamProvider),
          ref.read(unlockedAchievementsStreamProvider),
        ].any((value) => !value.hasValue || value.isLoading || value.hasError)) {
          return [];
        }
        tasks = ref.read(tasksStreamProvider).value ?? [];
        habits = ref.read(habitsStreamProvider).value ?? [];
        pomodoroLogs = ref.read(pomodoroLogsStreamProvider).value ?? [];
        events = ref.read(eventsStreamProvider).value ?? [];
        categories = ref.read(categoriesProvider).value ?? [];
        totalXp = ref.read(userXpStreamProvider).value ?? 0;
        unlockedMap = ref.read(unlockedAchievementsStreamProvider).value ?? {};
      } else if (widgetRef != null) {
        if ([
          widgetRef.read(tasksStreamProvider),
          widgetRef.read(habitsStreamProvider),
          widgetRef.read(pomodoroLogsStreamProvider),
          widgetRef.read(eventsStreamProvider),
          widgetRef.read(categoriesProvider),
          widgetRef.read(userXpStreamProvider),
          widgetRef.read(unlockedAchievementsStreamProvider),
        ].any((value) => !value.hasValue || value.isLoading || value.hasError)) {
          return [];
        }
        tasks = widgetRef.read(tasksStreamProvider).value ?? [];
        habits = widgetRef.read(habitsStreamProvider).value ?? [];
        pomodoroLogs = widgetRef.read(pomodoroLogsStreamProvider).value ?? [];
        events = widgetRef.read(eventsStreamProvider).value ?? [];
        categories = widgetRef.read(categoriesProvider).value ?? [];
        totalXp = widgetRef.read(userXpStreamProvider).value ?? 0;
        unlockedMap =
            widgetRef.read(unlockedAchievementsStreamProvider).value ?? {};
      }

      // 2. If provider data is empty or no ref provided, fetch from Firestore directly
      if (ref == null && widgetRef == null) {
        final firestore = _firestore;
        final userDoc = firestore.collection('users').doc(effectiveUid);

        try {
          final results = await Future.wait([
            userDoc.collection('stats').doc('progress').get(),
            readFirestorePages(userDoc.collection('tasks')),
            readFirestorePages(userDoc.collection('habits')),
            readFirestorePages(userDoc.collection('pomodoroLogs')),
            readFirestorePages(userDoc.collection('events')),
            readFirestorePages(userDoc.collection('categories')),
          ]);

          final statsSnap =
              results[0] as DocumentSnapshot<Map<String, dynamic>>;
          final tasksSnap =
              results[1] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
          final habitsSnap =
              results[2] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
          final pomosSnap =
              results[3] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
          final eventsSnap =
              results[4] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;
          final catsSnap =
              results[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;

          if (statsSnap.exists && statsSnap.data() != null) {
            totalXp = statsSnap.data()?['xp'] as int? ?? totalXp;
            final raw =
                statsSnap.data()?['unlockedAchievements']
                    as Map<String, dynamic>? ??
                {};
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

          if (tasksSnap.isNotEmpty) {
            tasks = tasksSnap
                .map((d) => TaskModel.fromMap(d.data(), d.id))
                .toList();
          }
          if (habitsSnap.isNotEmpty) {
            habits = habitsSnap
                .map((d) => HabitModel.fromFirestore(d))
                .toList();
          }
          if (pomosSnap.isNotEmpty) {
            pomodoroLogs = pomosSnap
                .map((d) => PomodoroLogModel.fromFirestore(d))
                .toList();
          }
          if (eventsSnap.isNotEmpty) {
            events = eventsSnap
                .map((d) => EventModel.fromMap(d.data(), d.id))
                .toList();
          }
          if (catsSnap.isNotEmpty) {
            categories = catsSnap
                .map((d) => TaskCategory.fromMap(d.data(), d.id))
                .toList();
          }
        } catch (_) {
          return [];
        }
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
      final doc = _firestore
          .collection('users')
          .doc(effectiveUid)
          .collection('stats')
          .doc('progress');

      final Map<String, dynamic> achievementUpdates = {};
      final now = DateTime.now();
      for (final item in newlyUnlocked) {
        achievementUpdates[item.id] = Timestamp.fromDate(now);
      }

      await doc.set({
        'unlockedAchievements': achievementUpdates,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

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
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
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
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
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
