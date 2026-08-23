import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../habits/providers/habits_provider.dart';
import '../../pomodoro/providers/pomodoro_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/level_logic.dart';

/// Stream of user total XP from Firestore
final userXpStreamProvider = StreamProvider.autoDispose<int>((ref) {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {}

  if (uid == null || uid.isEmpty) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stats')
      .doc('progress')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return 0;
    return snapshot.data()?['xp'] as int? ?? 0;
  }).handleError((_) => 0);
});

/// Stream of unlocked achievement IDs mapped to their unlock timestamp
final unlockedAchievementsStreamProvider =
    StreamProvider.autoDispose<Map<String, DateTime>>((ref) {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {}

  if (uid == null || uid.isEmpty) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('stats')
      .doc('progress')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists || snapshot.data() == null) return <String, DateTime>{};

    final raw = snapshot.data()?['unlockedAchievements'] as Map<String, dynamic>? ?? {};
    final Map<String, DateTime> result = {};

    raw.forEach((key, val) {
      if (val is Timestamp) {
        result[key] = val.toDate();
      } else if (val is String) {
        result[key] = DateTime.tryParse(val) ?? DateTime.now();
      } else {
        result[key] = DateTime.now();
      }
    });

    return result;
  }).handleError((_) => <String, DateTime>{});
});

/// Derived provider exposing the computed UserLevelInfo
final userLevelProvider = Provider.autoDispose<UserLevelInfo>((ref) {
  final xpAsync = ref.watch(userXpStreamProvider);
  final totalXp = xpAsync.value ?? 0;
  return LevelLogic.calculate(totalXp);
});

/// Category progress breakdown item
class CategoryProgressItem {
  final String id;
  final String nameKey;
  final int colorValue;
  final int totalCount;
  final int completedCount;

  const CategoryProgressItem({
    required this.id,
    required this.nameKey,
    required this.colorValue,
    required this.totalCount,
    required this.completedCount,
  });

  double get ratio => totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;
}

/// Derived provider calculating progress per task category
final categoryProgressProvider =
    Provider.autoDispose<List<CategoryProgressItem>>((ref) {
  final tasksAsync = ref.watch(tasksStreamProvider);
  final categoriesAsync = ref.watch(categoriesProvider);

  final tasks = tasksAsync.value ?? [];
  final categories = categoriesAsync.value ?? [];

  return categories.map((category) {
    final catTasks = tasks.where((t) => t.categoryId == category.id).toList();
    final completed = catTasks.where((t) => t.done).length;

    return CategoryProgressItem(
      id: category.id,
      nameKey: category.nameKey,
      colorValue: category.colorValue,
      totalCount: catTasks.length,
      completedCount: completed,
    );
  }).where((item) => item.totalCount > 0).toList();
});

/// Container for overview summary statistics
class ProgressOverviewStats {
  final int totalTasksCompleted;
  final int longestHabitStreak;
  final int totalPomodoroSessions;
  final int totalFocusedMinutes;
  final List<int> weeklyProductivityScore; // 7 entries for current week (Day 0..6)

  const ProgressOverviewStats({
    required this.totalTasksCompleted,
    required this.longestHabitStreak,
    required this.totalPomodoroSessions,
    required this.totalFocusedMinutes,
    required this.weeklyProductivityScore,
  });
}

/// Derived provider aggregating all cross-feature statistics for the Progress Overview
final progressOverviewStatsProvider =
    Provider.autoDispose<ProgressOverviewStats>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final habitStats = ref.watch(habitStatsProvider);
  final pomodoroLogs = ref.watch(pomodoroLogsStreamProvider).value ?? [];

  final totalTasksDone = tasks.where((t) => t.done).length;

  int totalPomoSessions = 0;
  int totalPomoMinutes = 0;
  for (final log in pomodoroLogs) {
    if (!log.partial) {
      totalPomoSessions += 1;
    }
    totalPomoMinutes += log.durationMinutes;
  }

  // Calculate 7-day weekly combined score
  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final dayOffset = (now.weekday - DateTime.saturday + 7) % 7;
  final weekStart = todayMidnight.subtract(Duration(days: dayOffset));

  final weeklyScore = List<int>.filled(7, 0);

  // Score from completed tasks
  for (final task in tasks.where((t) => t.done)) {
    final taskDate = DateTime(task.date.year, task.date.month, task.date.day);
    if (!taskDate.isBefore(weekStart) &&
        taskDate.isBefore(weekStart.add(const Duration(days: 7)))) {
      final idx = (taskDate.difference(weekStart).inDays).clamp(0, 6);
      weeklyScore[idx] += 1;
    }
  }

  // Score from Pomodoro sessions
  for (final log in pomodoroLogs) {
    final logDate = DateTime(log.date.year, log.date.month, log.date.day);
    if (!logDate.isBefore(weekStart) &&
        logDate.isBefore(weekStart.add(const Duration(days: 7)))) {
      final idx = (logDate.difference(weekStart).inDays).clamp(0, 6);
      weeklyScore[idx] += 1;
    }
  }

  return ProgressOverviewStats(
    totalTasksCompleted: totalTasksDone,
    longestHabitStreak: habitStats.longestStreak,
    totalPomodoroSessions: totalPomoSessions,
    totalFocusedMinutes: totalPomoMinutes,
    weeklyProductivityScore: weeklyScore,
  );
});
