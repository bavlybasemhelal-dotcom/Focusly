import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/pomodoro_config_model.dart';
import '../models/pomodoro_log_model.dart';
import '../models/pomodoro_state.dart';
import '../services/pomodoro_notification_service.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';

/// Stream of Pomodoro work session logs from Firestore for the current user
///
/// DATA ISOLATION: Watches [currentUserIdProvider] so session histories never leak across accounts.
final pomodoroLogsStreamProvider =
    StreamProvider.autoDispose<List<PomodoroLogModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<PomodoroLogModel>[]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('pomodoroLogs')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) => PomodoroLogModel.fromFirestore(doc))
        .toList();
  }).handleError((_) => <PomodoroLogModel>[]);
});

/// Container for computed daily and weekly Pomodoro statistics
class PomodoroStats {
  final int todaySessionsCount;
  final int todayFocusedMinutes;
  final List<int> weeklyMinutesPerDay; // 7 entries for current week (Day 0..6)
  final int bestDayIndex; // 0..6
  final int bestDayMinutes;

  const PomodoroStats({
    required this.todaySessionsCount,
    required this.todayFocusedMinutes,
    required this.weeklyMinutesPerDay,
    required this.bestDayIndex,
    required this.bestDayMinutes,
  });
}

/// Derived statistics provider summarizing today's focus metrics and 7-day weekly history
final pomodoroStatsProvider = Provider.autoDispose<PomodoroStats>((ref) {
  final logsAsync = ref.watch(pomodoroLogsStreamProvider);
  final logs = logsAsync.value ?? [];

  final now = DateTime.now();
  final todayMidnight = DateTime(now.year, now.month, now.day);

  // Compute week start (Saturday as week start = 6)
  final dayOffset = (now.weekday - DateTime.saturday + 7) % 7;
  final weekStart = todayMidnight.subtract(Duration(days: dayOffset));

  int todayCount = 0;
  int todayMins = 0;
  final weeklyMins = List<int>.filled(7, 0);

  for (final log in logs) {
    final logDate = DateTime(log.date.year, log.date.month, log.date.day);

    // Check if log is from today
    if (logDate.isAtSameMomentAs(todayMidnight)) {
      todayCount += 1;
      todayMins += log.durationMinutes;
    }

    // Check if log is within current week
    if (!logDate.isBefore(weekStart) &&
        logDate.isBefore(weekStart.add(const Duration(days: 7)))) {
      final weekIndex = (logDate.difference(weekStart).inDays).clamp(0, 6);
      weeklyMins[weekIndex] += log.durationMinutes;
    }
  }

  int bestIdx = 0;
  int maxMins = 0;
  for (int i = 0; i < weeklyMins.length; i++) {
    if (weeklyMins[i] > maxMins) {
      maxMins = weeklyMins[i];
      bestIdx = i;
    }
  }

  return PomodoroStats(
    todaySessionsCount: todayCount,
    todayFocusedMinutes: todayMins,
    weeklyMinutesPerDay: weeklyMins,
    bestDayIndex: bestIdx,
    bestDayMinutes: maxMins,
  );
});

/// State notifier driving the Pomodoro Timer state machine
class PomodoroTimerNotifier extends Notifier<PomodoroTimerState> {
  Timer? _ticker;

  @override
  PomodoroTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return PomodoroTimerState.initial();
  }

  /// Starts or resumes the countdown timer
  void start({
    String workDoneTitle = 'Focus session complete! Time for a break ☕',
    String breakDoneTitle = "Break's over! Ready to focus again? 🍅",
  }) {
    if (state.isRunning) return;

    final targetEndTime =
        DateTime.now().add(Duration(seconds: state.remainingSeconds));

    state = state.copyWith(
      isRunning: true,
      targetEndTime: targetEndTime,
    );

    // Schedule precision notification for background alert
    final notifTitle = state.isWorkPhase ? workDoneTitle : breakDoneTitle;
    final notifBody = state.isWorkPhase
        ? (state.selectedTaskTitle ?? 'Focus Session')
        : 'Take a deep breath and relax';

    PomodoroNotificationService().schedulePhaseCompletion(
      targetEndTime: targetEndTime,
      title: notifTitle,
      body: notifBody,
    );

    _startTicker(workDoneTitle: workDoneTitle, breakDoneTitle: breakDoneTitle);
  }

  /// Pauses the countdown timer and cancels the pending background notification
  void pause() {
    if (!state.isRunning) return;

    _ticker?.cancel();
    PomodoroNotificationService().cancelPendingNotification();

    // Recalculate remaining seconds from target end timestamp
    int remaining = state.remainingSeconds;
    if (state.targetEndTime != null) {
      remaining =
          state.targetEndTime!.difference(DateTime.now()).inSeconds.clamp(0, state.totalSeconds);
    }

    state = state.copyWith(
      isRunning: false,
      remainingSeconds: remaining,
      clearTargetEndTime: true,
    );
  }

  /// Resets the timer to the beginning of the 'work' phase
  ///
  /// Logs partial session if at least 5 seconds were focused in work phase
  void reset() {
    _ticker?.cancel();
    PomodoroNotificationService().cancelPendingNotification();

    // Handle partial session logging
    if (state.isWorkPhase) {
      final elapsed = state.totalSeconds - state.remainingSeconds;
      if (elapsed >= 5) {
        _logSession(
          durationSeconds: elapsed,
          partial: true,
        );
      }
    }

    state = PomodoroTimerState.initial(state.config).copyWith(
      selectedTaskId: state.selectedTaskId,
      selectedTaskTitle: state.selectedTaskTitle,
    );
  }

  /// Skips the active phase immediately and advances to the next phase
  void skip({
    String workDoneTitle = 'Focus session complete! Time for a break ☕',
    String breakDoneTitle = "Break's over! Ready to focus again? 🍅",
  }) {
    _ticker?.cancel();
    PomodoroNotificationService().cancelPendingNotification();

    // Log elapsed work session if any
    if (state.isWorkPhase) {
      final elapsed = state.totalSeconds - state.remainingSeconds;
      if (elapsed >= 5) {
        _logSession(
          durationSeconds: elapsed,
          partial: true,
        );
      }
    }

    _advanceToNextPhase(
      workDoneTitle: workDoneTitle,
      breakDoneTitle: breakDoneTitle,
    );
  }

  /// Increments the self-reported distraction count for the current session
  void incrementDistraction() {
    state = state.copyWith(
      distractionCount: state.distractionCount + 1,
    );
  }

  /// Sets or clears the active task linked to the focus session
  void setSelectedTask(String? taskId, String? taskTitle) {
    state = state.copyWith(
      selectedTaskId: taskId,
      selectedTaskTitle: taskTitle,
      clearSelectedTask: taskId == null,
    );
  }

  /// Updates timer duration configurations
  void updateConfig(PomodoroConfig newConfig) {
    _ticker?.cancel();
    PomodoroNotificationService().cancelPendingNotification();

    final int newDuration = switch (state.phase) {
      PomodoroPhase.work => newConfig.workSeconds,
      PomodoroPhase.shortBreak => newConfig.shortBreakSeconds,
      PomodoroPhase.longBreak => newConfig.longBreakSeconds,
    };

    state = state.copyWith(
      config: newConfig,
      isRunning: false,
      remainingSeconds: newDuration,
      totalSeconds: newDuration,
      clearTargetEndTime: true,
    );
  }

  void _startTicker({
    required String workDoneTitle,
    required String breakDoneTitle,
  }) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.targetEndTime == null) {
        timer.cancel();
        return;
      }

      final remaining = state.targetEndTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        timer.cancel();
        _onPhaseCompleted(
          workDoneTitle: workDoneTitle,
          breakDoneTitle: breakDoneTitle,
        );
      } else {
        state = state.copyWith(remainingSeconds: remaining);
      }
    });
  }

  void _onPhaseCompleted({
    required String workDoneTitle,
    required String breakDoneTitle,
  }) {
    PomodoroNotificationService().cancelPendingNotification();

    if (state.isWorkPhase) {
      // Log full completed work session
      _logSession(
        durationSeconds: state.totalSeconds,
        partial: false,
      );
    }

    _advanceToNextPhase(
      workDoneTitle: workDoneTitle,
      breakDoneTitle: breakDoneTitle,
    );
  }

  void _advanceToNextPhase({
    required String workDoneTitle,
    required String breakDoneTitle,
  }) {
    PomodoroPhase nextPhase;
    int nextCycleCount = state.completedSessionsInCycle;
    int nextDuration;

    if (state.isWorkPhase) {
      nextCycleCount += 1;
      if (nextCycleCount >= state.config.longBreakInterval) {
        nextPhase = PomodoroPhase.longBreak;
        nextCycleCount = 0; // Reset cycle after long break
        nextDuration = state.config.longBreakSeconds;
      } else {
        nextPhase = PomodoroPhase.shortBreak;
        nextDuration = state.config.shortBreakSeconds;
      }
    } else {
      // Break completed -> Next is work session
      nextPhase = PomodoroPhase.work;
      nextDuration = state.config.workSeconds;
    }

    state = state.copyWith(
      phase: nextPhase,
      isRunning: false,
      remainingSeconds: nextDuration,
      totalSeconds: nextDuration,
      completedSessionsInCycle: nextCycleCount,
      distractionCount: 0,
      clearTargetEndTime: true,
    );

    if (state.config.autoStartNext) {
      start(workDoneTitle: workDoneTitle, breakDoneTitle: breakDoneTitle);
    }
  }

  void _logSession({
    required int durationSeconds,
    required bool partial,
  }) {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    if (uid == null || uid.isEmpty) return;

    final now = DateTime.now();
    final log = PomodoroLogModel(
      id: '',
      date: DateTime(now.year, now.month, now.day),
      linkedTaskId: state.selectedTaskId,
      taskTitle: state.selectedTaskTitle ?? 'Focus Session',
      durationSeconds: durationSeconds,
      durationMinutes: (durationSeconds / 60).ceil(),
      distractionCount: state.distractionCount,
      partial: partial,
      createdAt: now,
    );

    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pomodoroLogs')
          .add(log.toMap());

      // XP award & Achievement check hook: +30 XP for full session, ~1.2 XP/min for partial
      final taskLabel = state.selectedTaskTitle ?? 'Focus Session';
      final minutes = (durationSeconds / 60).ceil();
      if (!partial) {
        ProgressService().awardXp(
          XpConstants.pomodoroFullSession,
          source: 'Pomodoro focus session: "$taskLabel" ($minutes min)',
          sourceType: 'pomodoro',
        );
      } else {
        final earnedXp = ((durationSeconds / 60) * XpConstants.pomodoroPartialRatePerMin).round().clamp(1, 29);
        ProgressService().awardXp(
          earnedXp,
          source: 'Partial focus session: "$taskLabel" ($minutes min)',
          sourceType: 'pomodoro',
        );
      }
    } catch (_) {}
  }
}

/// Provider exposing the PomodoroTimerNotifier state controller
final pomodoroTimerProvider =
    NotifierProvider<PomodoroTimerNotifier, PomodoroTimerState>(
  PomodoroTimerNotifier.new,
);
