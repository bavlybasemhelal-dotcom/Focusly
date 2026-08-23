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
import '../../progress/services/progress_service.dart';
import '../../groups/services/challenge_service.dart';
import '../../groups/services/group_feed_service.dart';

/// Stream provider that listens to real-time habits subcollection in Firestore
/// and applies automatic weekly reset checks on the fly.
///
/// DATA ISOLATION: Watches [currentUserIdProvider] so habits never leak between accounts.
final habitsStreamProvider = StreamProvider.autoDispose<List<HabitModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

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
    final now = DateTime.now();
    final List<HabitModel> habits = [];

    for (final doc in snapshot.docs) {
      final habit = HabitModel.fromFirestore(doc);
      // Run automatic weekly rollover check
      final updated = StreakLogic.evaluateWeeklyReset(habit, now);

      // If weekly reset changed habit state, persist asynchronously to Firestore
      if (updated.lastResetDate != habit.lastResetDate) {
        doc.reference.update(updated.toMap()).catchError((_) {});
      }

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
  Future<void> addHabit(HabitModel habit, BuildContext context) async {
    final notificationTitle = context.tr('notification_habit_title');
    try {
      final col = _habitsCollection;
      if (col == null) return;

      final docRef = await col.add(habit.toMap());
      final createdHabit = habit.copyWith(id: docRef.id);

      if (createdHabit.time != null) {
        await HabitNotificationService().scheduleHabitReminder(
          habit: createdHabit,
          notificationTitle: notificationTitle,
        );
      }

      if (context.mounted) {
        _showToast(context, context.tr('habit_added_success'), isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
    }
  }

  /// Updates an existing Habit in Firestore and refreshes its notification schedule
  Future<void> updateHabit(HabitModel habit, BuildContext context) async {
    final notificationTitle = context.tr('notification_habit_title');
    try {
      final col = _habitsCollection;
      if (col == null) return;

      await col.doc(habit.id).update(habit.toMap());

      if (habit.time != null) {
        await HabitNotificationService().scheduleHabitReminder(
          habit: habit,
          notificationTitle: notificationTitle,
        );
      } else {
        await HabitNotificationService().cancelHabitReminder(habit.id);
      }

      if (context.mounted) {
        _showToast(context, context.tr('habit_updated_success'), isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_saving'), isError: true);
      }
    }
  }

  /// Deletes a Habit from Firestore and cancels any scheduled reminder notification
  Future<void> deleteHabit(String habitId, BuildContext context) async {
    try {
      final col = _habitsCollection;
      if (col == null) return;

      await col.doc(habitId).delete();
      await HabitNotificationService().cancelHabitReminder(habitId);

      if (context.mounted) {
        _showToast(context, context.tr('habit_deleted_success'), isError: false);
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, context.tr('habit_error_deleting'), isError: true);
      }
    }
  }

  /// Toggles a day's completion state directly and checks for milestone celebrations
  Future<void> toggleDay(
    HabitModel habit,
    int dayIndex,
    BuildContext context,
  ) async {
    final oldStreak = habit.streak;
    final updatedHabit = StreakLogic.toggleHabitDay(habit, dayIndex);

    // Check for milestone celebration
    final milestone = StreakLogic.checkMilestoneCelebration(
      oldStreak,
      updatedHabit.streak,
    );

    if (milestone != null && context.mounted) {
      _showMilestoneCelebration(context, updatedHabit.title, milestone);

      // Group feed hook: habit streak milestone
      GroupFeedService().pushToAllUserGroups(
        type: 'streak_milestone',
        message: 'Reached a $milestone-day streak on "${updatedHabit.title}"! 🔥',
        icon: '🔥',
      );
    }

    // XP award and Achievement check hook: +5 XP for completing habit day
    if (updatedHabit.isDayCompleted(dayIndex)) {
      ProgressService().awardXp(5);
      ChallengeService().triggerProgressSync();
    }

    try {
      final col = _habitsCollection;
      if (col == null) return;
      await col.doc(habit.id).update(updatedHabit.toMap());
    } catch (_) {}
  }

  void _showMilestoneCelebration(
    BuildContext context,
    String habitTitle,
    int milestoneDays,
  ) {
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
                '$milestoneDays-day streak on "$habitTitle"!',
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

  void _showToast(BuildContext context, String message, {bool isError = false}) {
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
            : (isDark ? const Color(0xFF0F1B4C) : AppColors.brandPrimary(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
