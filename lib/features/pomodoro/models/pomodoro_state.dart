import 'pomodoro_config_model.dart';

/// Active phase of the Pomodoro Timer state machine
enum PomodoroPhase {
  work,
  shortBreak,
  longBreak,
}

/// State representation for the Pomodoro focus timer in Focusly.
///
/// Keeps track of real-time seconds remaining, target end-timestamp
/// (to prevent drift during backgrounding), linked task, and distraction tally.
class PomodoroTimerState {
  final PomodoroPhase phase;
  final bool isRunning;
  final int remainingSeconds;
  final int totalSeconds;
  final int completedSessionsInCycle;
  final DateTime? targetEndTime;
  final String? selectedTaskId;
  final String? selectedTaskTitle;
  final int distractionCount;
  final PomodoroConfig config;

  const PomodoroTimerState({
    required this.phase,
    required this.isRunning,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.completedSessionsInCycle = 0,
    this.targetEndTime,
    this.selectedTaskId,
    this.selectedTaskTitle,
    this.distractionCount = 0,
    this.config = const PomodoroConfig(),
  });

  /// Factory constructor to initialize a fresh timer in the 'work' phase
  factory PomodoroTimerState.initial([PomodoroConfig config = const PomodoroConfig()]) {
    return PomodoroTimerState(
      phase: PomodoroPhase.work,
      isRunning: false,
      remainingSeconds: config.workSeconds,
      totalSeconds: config.workSeconds,
      completedSessionsInCycle: 0,
      targetEndTime: null,
      selectedTaskId: null,
      selectedTaskTitle: null,
      distractionCount: 0,
      config: config,
    );
  }

  /// Whether current phase is a focused work session
  bool get isWorkPhase => phase == PomodoroPhase.work;

  /// Whether current phase is any break
  bool get isBreakPhase => phase == PomodoroPhase.shortBreak || phase == PomodoroPhase.longBreak;

  /// Timer completion progress from 0.0 (just started) to 1.0 (completed)
  double get progress {
    if (totalSeconds <= 0) return 0.0;
    final elapsed = totalSeconds - remainingSeconds;
    return (elapsed / totalSeconds).clamp(0.0, 1.0);
  }

  /// Formatted MM:SS display string
  String get formattedTime {
    final int minutes = remainingSeconds ~/ 60;
    final int seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Translation key for the active phase
  String get phaseTitleKey {
    switch (phase) {
      case PomodoroPhase.work:
        return 'focus_time';
      case PomodoroPhase.shortBreak:
        return 'short_break';
      case PomodoroPhase.longBreak:
        return 'long_break';
    }
  }

  /// Returns a copy of state with updated parameters
  PomodoroTimerState copyWith({
    PomodoroPhase? phase,
    bool? isRunning,
    int? remainingSeconds,
    int? totalSeconds,
    int? completedSessionsInCycle,
    DateTime? targetEndTime,
    bool clearTargetEndTime = false,
    String? selectedTaskId,
    bool clearSelectedTask = false,
    String? selectedTaskTitle,
    int? distractionCount,
    PomodoroConfig? config,
  }) {
    return PomodoroTimerState(
      phase: phase ?? this.phase,
      isRunning: isRunning ?? this.isRunning,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      completedSessionsInCycle:
          completedSessionsInCycle ?? this.completedSessionsInCycle,
      targetEndTime:
          clearTargetEndTime ? null : (targetEndTime ?? this.targetEndTime),
      selectedTaskId:
          clearSelectedTask ? null : (selectedTaskId ?? this.selectedTaskId),
      selectedTaskTitle:
          clearSelectedTask ? null : (selectedTaskTitle ?? this.selectedTaskTitle),
      distractionCount: distractionCount ?? this.distractionCount,
      config: config ?? this.config,
    );
  }
}
