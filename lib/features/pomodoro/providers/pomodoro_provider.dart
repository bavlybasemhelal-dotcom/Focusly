import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/data/calendar_clock.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/pending_operations.dart';
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
          });
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

  final now = ref.watch(calendarClockProvider);
  final todayMidnight = DateTime(now.year, now.month, now.day);

  // Compute week start (Saturday as week start = 6)
  final dayOffset = (now.weekday - DateTime.saturday + 7) % 7;
  final weekStart = calendarDay(todayMidnight, -dayOffset);

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
        logDate.isBefore(calendarDay(weekStart, 7))) {
      final weekIndex = calendarDaysBetween(weekStart, logDate).clamp(0, 6);
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

final pomodoroNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// State notifier driving the Pomodoro Timer state machine
class PomodoroTimerNotifier extends Notifier<PomodoroTimerState> {
  Timer? _ticker;
  int _generation = 0;
  String _sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  PomodoroTimerState build() {
    final uid = ref.watch(currentUserIdProvider);
    final generation = ++_generation;
    _restore(uid, generation);
    final removeListener = listenSelf((previous, next) {
      if (previous?.isRunning != next.isRunning ||
          previous?.phase != next.phase ||
          previous?.config != next.config ||
          previous?.selectedTaskId != next.selectedTaskId ||
          previous?.completedSessionsInCycle != next.completedSessionsInCycle ||
          previous?.targetEndTime != next.targetEndTime ||
          (next.isRunning && next.remainingSeconds % 10 == 0)) {
        _persist(uid, next);
      }
    });
    ref.onDispose(removeListener);
    _ticker?.cancel();
    ref.onDispose(() {
      _ticker?.cancel();
      PomodoroNotificationService().cancelPendingNotification();
    });
    return PomodoroTimerState.initial();
  }

  Future<void> _restore(String? uid, int generation) async {
    if (uid == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('pomodoro_$uid');
      if (raw == null || !ref.mounted || generation != _generation) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final config = PomodoroConfig.fromMap(
        Map<String, dynamic>.from(map['config'] as Map),
      );
      final phase = PomodoroPhase.values.byName(map['phase'] as String);
      final total = (map['totalSeconds'] as num).toInt();
      final savedEnd = DateTime.tryParse(map['targetEndTime'] as String? ?? '');
      final running = map['isRunning'] == true && savedEnd != null;
      // Resume the last recorded active duration. Time while the process was
      // closed is excluded from focus statistics and rewards.
      final remaining = (map['remainingSeconds'] as num).toInt().clamp(
        0,
        total,
      );
      _sessionId = map['sessionId'] as String? ?? _sessionId;
      state = PomodoroTimerState(
        phase: phase,
        isRunning: false,
        remainingSeconds: remaining,
        totalSeconds: total,
        completedSessionsInCycle: (map['cycle'] as num?)?.toInt() ?? 0,
        config: config,
        selectedTaskId: map['taskId'] as String?,
        selectedTaskTitle: map['taskTitle'] as String?,
        distractionCount: (map['distractions'] as num?)?.toInt() ?? 0,
      );
      // A restored countdown remains paused until the user resumes; no elapsed
      // closed-app interval silently earns XP or starts the following phase.
      if (remaining == 0 && running) {
        _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
        state = state.copyWith(remainingSeconds: total);
      }
    } catch (_) {
      /* Invalid/old local state safely starts a fresh timer. */
    }
  }

  Future<void> _persist(String? uid, PomodoroTimerState snapshot) async {
    if (uid == null) return;
    final data = {
      'config': snapshot.config.toMap(),
      'phase': snapshot.phase.name,
      'isRunning': snapshot.isRunning,
      'remainingSeconds': snapshot.remainingSeconds,
      'totalSeconds': snapshot.totalSeconds,
      'targetEndTime': snapshot.targetEndTime?.toIso8601String(),
      'cycle': snapshot.completedSessionsInCycle,
      'taskId': snapshot.selectedTaskId,
      'taskTitle': snapshot.selectedTaskTitle,
      'distractions': snapshot.distractionCount,
      'sessionId': _sessionId,
    };
    try {
      await (await SharedPreferences.getInstance()).setString(
        'pomodoro_$uid',
        jsonEncode(data),
      );
    } catch (_) {}
  }

  /// Starts or resumes the countdown timer
  void start({
    String workDoneTitle = 'Focus session complete! Time for a break ☕',
    String breakDoneTitle = "Break's over! Ready to focus again? 🍅",
  }) {
    if (state.isRunning) return;

    final targetEndTime = ref
        .read(pomodoroNowProvider)()
        .add(Duration(seconds: state.remainingSeconds));

    state = state.copyWith(isRunning: true, targetEndTime: targetEndTime);

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
      remaining = state.targetEndTime!
          .difference(ref.read(pomodoroNowProvider)())
          .inSeconds
          .clamp(0, state.totalSeconds);
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
        _logSession(durationSeconds: elapsed, partial: true);
      }
    }

    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
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
        _logSession(durationSeconds: elapsed, partial: true);
      }
    }

    _advanceToNextPhase(
      workDoneTitle: workDoneTitle,
      breakDoneTitle: breakDoneTitle,
      completedWork: false,
    );
  }

  /// Increments the self-reported distraction count for the current session
  void incrementDistraction() {
    state = state.copyWith(distractionCount: state.distractionCount + 1);
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
    if (newConfig.workMinutes < 1 ||
        newConfig.workMinutes > 180 ||
        newConfig.shortBreakMinutes < 1 ||
        newConfig.shortBreakMinutes > 60 ||
        newConfig.longBreakMinutes < 1 ||
        newConfig.longBreakMinutes > 120 ||
        newConfig.longBreakInterval < 1 ||
        newConfig.longBreakInterval > 12) {
      throw ArgumentError('Invalid timer configuration');
    }
    if (state.isWorkPhase) {
      final elapsed = state.totalSeconds - state.remainingSeconds;
      if (elapsed >= 5) _logSession(durationSeconds: elapsed, partial: true);
    }
    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
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

      final remaining = state.targetEndTime!
          .difference(ref.read(pomodoroNowProvider)())
          .inSeconds;

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
      _logSession(durationSeconds: state.totalSeconds, partial: false);
    }

    _advanceToNextPhase(
      workDoneTitle: workDoneTitle,
      breakDoneTitle: breakDoneTitle,
    );
  }

  void _advanceToNextPhase({
    required String workDoneTitle,
    required String breakDoneTitle,
    bool completedWork = true,
  }) {
    PomodoroPhase nextPhase;
    int nextCycleCount = state.completedSessionsInCycle;
    int nextDuration;

    if (state.isWorkPhase) {
      if (completedWork) nextCycleCount += 1;
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

    _sessionId = DateTime.now().microsecondsSinceEpoch.toString();
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

  Future<void> _logSession({
    required int durationSeconds,
    required bool partial,
  }) async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    if (uid == null || uid.isEmpty) return;

    final sessionId = _sessionId;
    final now = ref.read(pomodoroNowProvider)();
    final log = PomodoroLogModel(
      id: '',
      date: DateTime(now.year, now.month, now.day),
      linkedTaskId: state.selectedTaskId,
      taskTitle: state.selectedTaskTitle ?? 'Focus Session',
      durationSeconds: durationSeconds,
      durationMinutes: durationSeconds ~/ 60,
      distractionCount: state.distractionCount,
      partial: partial,
      createdAt: now,
    );

    try {
      await PendingOperations.enqueue(uid, 'pomodoro', sessionId, {
        ...log.toMap(),
        'date': log.date.toIso8601String(),
        'createdAt': log.createdAt.toIso8601String(),
      });
      final saved = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pomodoroLogs')
          .doc(sessionId);
      await saved.firestore.runTransaction((transaction) async {
        final previous = await transaction.get(saved);
        if (!previous.exists) transaction.set(saved, log.toMap());
      });

      // XP award & Achievement check hook: +30 XP for full session, ~1.2 XP/min for partial
      final taskLabel = log.taskTitle;
      final minutes = durationSeconds ~/ 60;
      if (durationSeconds < 300) {
        await PendingOperations.acknowledge(uid, 'pomodoro', sessionId);
        return;
      }
      if (!partial) {
        await ProgressService().awardXp(
          (durationSeconds / 50).floor().clamp(1, 30),
          source: 'Pomodoro focus session: "$taskLabel" ($minutes min)',
          sourceType: 'pomodoro',
          uid: uid,
          sourceId: saved.id,
          eventId: 'pomodoro_${saved.id}',
        );
      } else {
        final earnedXp =
            ((durationSeconds / 60) * XpConstants.pomodoroPartialRatePerMin)
                .floor()
                .clamp(1, 29);
        await ProgressService().awardXp(
          earnedXp,
          source: 'Partial focus session: "$taskLabel" ($minutes min)',
          sourceType: 'pomodoro',
          uid: uid,
          sourceId: saved.id,
          eventId: 'pomodoro_${saved.id}',
        );
      }
      await PendingOperations.acknowledge(uid, 'pomodoro', sessionId);
    } catch (_) {}
  }
}

/// Provider exposing the PomodoroTimerNotifier state controller
final pomodoroTimerProvider =
    NotifierProvider<PomodoroTimerNotifier, PomodoroTimerState>(
      PomodoroTimerNotifier.new,
    );
