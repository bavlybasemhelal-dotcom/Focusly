import '../../productivity/services/trash_service.dart';
import '../../../core/data/item_progress_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/streak_logic.dart';
import '../models/habit_model.dart';
import '../services/habit_notification_service.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';
import '../../groups/services/challenge_service.dart';
import '../../groups/services/group_feed_service.dart';
import '../../../core/data/calendar_clock.dart';
import '../../../core/data/completion_ledger.dart';
import '../services/habit_history_service.dart';

/// Stream provider that listens to real-time habits subcollection in Firestore
/// and applies automatic weekly reset checks on the fly.
///
/// DATA ISOLATION: Watches [currentUserIdProvider] so habits never leak between accounts.
final habitsStreamProvider = StreamProvider.autoDispose<List<HabitModel>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);
  final now = ref.watch(calendarClockProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<HabitModel>[]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('habits')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) {
        final List<HabitModel> habits = [];

        for (final doc in snapshot.docs) {
          final habit = HabitModel.fromFirestore(doc);
          // Run automatic weekly rollover check
          final raw = doc.data();
          final currentWeek = StreakLogic.getStartOfWeek(
            now,
            weekStartDay: habit.resetDay,
          );
          final sameWeek =
              habit.lastResetDate != null &&
              StreakLogic.getStartOfWeek(
                    habit.lastResetDate!,
                    weekStartDay: habit.resetDay,
                  ) ==
                  currentWeek;
          final lastCompleted = DateTime.tryParse(
            raw['lastCompletedDate'] as String? ?? '',
          );
          var streak = lastCompleted == null ? 0 : habit.streak;
          if (lastCompleted != null) {
            var cursor = calendarDay(lastCompleted, 1);
            while (cursor.isBefore(calendarDay(now))) {
              if (habit.weekdays.contains(cursor.weekday)) {
                streak = 0;
                break;
              }
              cursor = calendarDay(cursor, 1);
            }
          }
          final updated = habit.copyWith(
            days: [
              for (var day = 0; day < 7; day++)
                sameWeek &&
                    !calendarDay(currentWeek, day).isAfter(now) &&
                    habit.weekdays.contains(
                      calendarDay(currentWeek, day).weekday,
                    ) &&
                    habit.days[day],
            ],
            streak: streak,
          );

          habits.add(updated);
        }

        return habits;
      });
});

/// Derived provider for summary statistics
final habitStatsProvider = Provider.autoDispose<HabitStats>((ref) {
  final habitsAsync = ref.watch(habitsStreamProvider);
  final habits = habitsAsync.value ?? [];

  final totalHabits = habits.length;
  int longestStreak = 0;
  int totalStreakDays = 0;

  for (final habit in habits) {
    if (habit.streak > longestStreak) {
      longestStreak = habit.streak;
    }
    totalStreakDays += habit.streak;
  }

  return HabitStats(
    totalHabits: totalHabits,
    longestStreak: longestStreak,
    totalStreakDays: totalStreakDays,
  );
});

/// Data container for header summary stat cards
class HabitStats {
  final int totalHabits;
  final int longestStreak;
  final int totalStreakDays;

  const HabitStats({
    required this.totalHabits,
    required this.longestStreak,
    required this.totalStreakDays,
  });
}

/// Controller provider managing Firestore mutations, notifications,
/// day toggles, and milestone celebration toasts for Habits.
final habitsControllerProvider = Provider<HabitsController>((ref) {
  return HabitsController(ref);
});

class HabitsController {
  final Ref ref;
  HabitsController(this.ref);

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _habitsCollection {
    final uid = _currentUserId;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('habits');
  }

  /// Adds a new Habit to Firestore and schedules daily local notification if time is set
  Future<bool> addHabit(HabitModel habit, BuildContext context) async {
    final notificationTitle = context.tr('notification_habit_title');
    try {
      final col = _habitsCollection;
      if (col == null) return false;

      final docRef = await col.add(habit.toMap());
      final createdHabit = habit.copyWith(id: docRef.id);

      await _scheduleReminder(createdHabit, notificationTitle, col.parent!.id);

      if (context.mounted) {
        _showToast(context, context.tr('habit_added_success'), isError: false);
      }
      // Achievement check hook for adding habit (1st, 5th)
      ProgressService().checkAndUnlockAchievements(
        context: context.mounted ? context : null,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
      return false;
    }
  }

  /// Updates an existing Habit in Firestore and refreshes its notification schedule
  Future<bool> updateHabit(HabitModel habit, BuildContext context) async {
    final notificationTitle = context.tr('notification_habit_title');
    try {
      final col = _habitsCollection;
      if (col == null) return false;

      final metadata = habit.toMap()
        ..remove('days')
        ..remove('streak')
        ..remove('totalCount')
        ..remove('currentCount')
        ..remove('lastResetDate')
        ..remove('lastCompletedDate')
        ..remove('createdAt');
      await col.doc(habit.id).update(metadata);

      await _scheduleReminder(habit, notificationTitle, col.parent!.id);

      if (context.mounted) {
        _showToast(
          context,
          context.tr('habit_updated_success'),
          isError: false,
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
      return false;
    }
  }

  /// Deletes a Habit from Firestore and cancels any scheduled reminder notification
  Future<void> _scheduleReminder(
    HabitModel habit,
    String title,
    String account,
  ) async {
    if (_currentUserId != account) return;
    try {
      if (habit.time != null) {
        await HabitNotificationService().scheduleHabitReminder(
          habit: habit,
          notificationTitle: title,
          uid: account,
        );
      } else {
        await HabitNotificationService().cancelHabitReminder(habit.id);
      }
    } catch (e) {
      debugPrint('Habit saved, but reminder scheduling failed: $e');
    }
  }

  Future<void> deleteHabit(String habitId, BuildContext context) async {
    try {
      final col = _habitsCollection;
      if (col == null) return;

      final account = col.parent!.id;
      final key = await TrashService(
        col.firestore,
      ).move(account, 'habits', habitId);
      await HabitNotificationService().cancelHabitReminder(habitId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('habit_deleted_success')),
            action: SnackBarAction(
              label: Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تراجع'
                  : 'Undo',
              onPressed: () async {
                if (ref.read(currentUserIdProvider) == account) {
                  await TrashService(col.firestore).restore(account, key);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_deleting'), isError: true);
      }
    }
  }

  /// Toggles a day's completion state directly, handles early week resets,
  /// and triggers milestone or early-completion celebrations.
  Future<void> toggleDay(
    HabitModel habit,
    int dayIndex,
    BuildContext context,
  ) async {
    final oldStreak = habit.streak;
    final now = ref.read(calendarClockProvider);
    final date = calendarDay(
      StreakLogic.getStartOfWeek(now, weekStartDay: habit.resetDay),
      dayIndex,
    );
    if (dayIndex < 0 || dayIndex > 6 || date.isAfter(calendarDay(now))) return;
    final retrospective = date.isBefore(calendarDay(now));
    if (retrospective) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(context.tr('habit_retrospective_title')),
          content: Text(CompletionLedger.dateKey(date)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(context.tr('cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(context.tr('confirm')),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    late HabitModel updatedHabit;

    // Persist first: a failed write must not award XP or announce completion.
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final col = _habitsCollection;
      if (col == null) return;
      updatedHabit = await HabitHistoryService(FirebaseFirestore.instance)
          .setCompleted(
            uid: uid,
            habitId: habit.id,
            date: date,
            completed: !habit.isDayCompleted(dayIndex),
            retrospective: retrospective,
          );
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
      return;
    }
    if (_currentUserId != uid) return;
    final toggleResult = HabitToggleResult(
      habit: updatedHabit,
      wasEarlyWeekReset: false,
    );

    // Check for milestone celebration (3, 7, 14, 30, 60, 100 days)
    final milestone = StreakLogic.checkMilestoneCelebration(
      oldStreak,
      updatedHabit.streak,
    );

    if (milestone != null && context.mounted) {
      _showMilestoneCelebration(
        context,
        updatedHabit.title,
        milestone,
        isEarlyWeekReset: toggleResult.wasEarlyWeekReset,
      );

      // Group feed hook: habit streak milestone
      GroupFeedService().pushToAllUserGroups(
        uid: uid,
        type: 'streak_milestone',
        message:
            'Reached a $milestone-day streak on "${updatedHabit.title}"! 🔥',
        icon: '🔥',
      );
    } else if (toggleResult.wasEarlyWeekReset && context.mounted) {
      // Early week completion celebration toast without milestone
      _showEarlyWeekCelebration(context, updatedHabit.title);
    }

    // =========================================================================
    // XP & ACHIEVEMENT HOOKS
    // NOTE: Group-assigned habits explicitly BYPASS all personal XP awards.
    // =========================================================================
    if (toggleResult.wasEarlyWeekReset ||
        updatedHabit.isDayCompleted(dayIndex)) {
      if (updatedHabit.isGroupAssigned) {
        // Explicitly SKIP personal XP award for group-assigned habits
        final ledger = CompletionLedger(FirebaseFirestore.instance);
        await ledger.award(
          uid: uid,
          eventId: 'habit_${updatedHabit.id}_${CompletionLedger.dateKey(date)}',
          sourceId: updatedHabit.id,
          sourceType: 'habit',
          amount: 0,
          label: updatedHabit.title,
        );
        await ledger.syncGroups(
          uid: uid,
          eventId: 'habit_${updatedHabit.id}_${CompletionLedger.dateKey(date)}',
        );
        debugPrint(
          'Group-assigned habit checked ("${updatedHabit.title}") — skipping personal XP award.',
        );
      } else {
        // Normal personal habit: Award standard habit completion XP (+5 XP)
        ProgressService().awardXp(
          XpConstants.habitDayCompletion,
          source: 'Completed habit: "${updatedHabit.title}"',
          sourceType: 'habit',
          uid: uid,
          sourceId: updatedHabit.id,
          eventId: 'habit_${updatedHabit.id}_${CompletionLedger.dateKey(date)}',
          context: context.mounted ? context : null,
        );
      }
      ChallengeService().triggerProgressSync(uid: uid);
    }
  }

  /// Increments progress count for a group-assigned habit in count-mode
  /// (e.g. "log this 10 times total").
  ///
  /// NOTE: Count-mode group-assigned habits bypass the 7-day streak system
  /// and explicitly DO NOT award personal XP.
  Future<void> incrementHabitCount(HabitModel habit, BuildContext context) =>
      _changeHabitCount(habit, 1, context);
  Future<void> decrementHabitCount(HabitModel habit, BuildContext context) =>
      _changeHabitCount(habit, -1, context);
  Future<void> _changeHabitCount(
    HabitModel habit,
    int delta,
    BuildContext context,
  ) async {
    final uid = _currentUserId;
    if (uid == null) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final data = await ItemProgressService(
        firestore,
      ).habitCount(uid: uid, id: habit.id, delta: delta);
      if (data['isCompleted'] == true && _currentUserId == uid) {
        final ledger = CompletionLedger(firestore);
        await ledger.award(
          uid: uid,
          eventId: 'habit_count_${habit.id}',
          sourceId: habit.id,
          sourceType: 'habit_count',
          amount: 0,
          label: habit.title,
        );
        await ledger.syncGroups(uid: uid, eventId: 'habit_count_${habit.id}');
        ChallengeService().triggerProgressSync(uid: uid);
      }
    } catch (error) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
    }
  }

  void _showMilestoneCelebration(
    BuildContext context,
    String habitTitle,
    int milestoneDays, {
    bool isEarlyWeekReset = false,
  }) {
    final earlyWeekMsg = isEarlyWeekReset
        ? ' • ${context.tr('habit_early_week_complete_toast')}'
        : '';
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1B4C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        content: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$milestoneDays-day streak on "$habitTitle"!$earlyWeekMsg',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showEarlyWeekCelebration(BuildContext context, String habitTitle) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F1B4C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        content: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('habit_early_week_complete_toast'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showToast(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppColors.errorRed
            : (isDark
                  ? const Color(0xFF0F1B4C)
                  : AppColors.brandPrimary(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
