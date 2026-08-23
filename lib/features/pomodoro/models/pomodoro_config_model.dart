/// Configuration parameters for the Pomodoro Timer in Focusly.
///
/// Contains customizable durations for work sessions, breaks,
/// long break intervals, and auto-start preferences.
class PomodoroConfig {
  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int longBreakInterval; // Number of work sessions before a long break
  final bool autoStartNext; // Automatically start the next phase

  const PomodoroConfig({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.longBreakInterval = 4,
    this.autoStartNext = false,
  });

  /// Duration of the work phase in seconds
  int get workSeconds => workMinutes * 60;

  /// Duration of the short break in seconds
  int get shortBreakSeconds => shortBreakMinutes * 60;

  /// Duration of the long break in seconds
  int get longBreakSeconds => longBreakMinutes * 60;

  /// Copy with updated values
  PomodoroConfig copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? longBreakInterval,
    bool? autoStartNext,
  }) {
    return PomodoroConfig(
      workMinutes: workMinutes ?? this.workMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      autoStartNext: autoStartNext ?? this.autoStartNext,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'workMinutes': workMinutes,
      'shortBreakMinutes': shortBreakMinutes,
      'longBreakMinutes': longBreakMinutes,
      'longBreakInterval': longBreakInterval,
      'autoStartNext': autoStartNext,
    };
  }

  factory PomodoroConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PomodoroConfig();
    return PomodoroConfig(
      workMinutes: map['workMinutes'] as int? ?? 25,
      shortBreakMinutes: map['shortBreakMinutes'] as int? ?? 5,
      longBreakMinutes: map['longBreakMinutes'] as int? ?? 15,
      longBreakInterval: map['longBreakInterval'] as int? ?? 4,
      autoStartNext: map['autoStartNext'] as bool? ?? false,
    );
  }
}
