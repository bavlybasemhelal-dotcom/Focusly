import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_config_model.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_state.dart';
import 'package:focusly/features/pomodoro/providers/pomodoro_provider.dart';

void main() {
  group('Pomodoro Timer Logic & State Machine Tests', () {
    test('PomodoroConfig initial values and duration conversions', () {
      const config = PomodoroConfig();
      expect(config.workMinutes, 25);
      expect(config.shortBreakMinutes, 5);
      expect(config.longBreakMinutes, 15);
      expect(config.longBreakInterval, 4);
      expect(config.autoStartNext, isFalse);

      expect(config.workSeconds, 25 * 60);
      expect(config.shortBreakSeconds, 5 * 60);
      expect(config.longBreakSeconds, 15 * 60);
    });

    test('PomodoroTimerState initial and progress calculations', () {
      final state = PomodoroTimerState.initial();
      expect(state.phase, PomodoroPhase.work);
      expect(state.isRunning, isFalse);
      expect(state.remainingSeconds, 25 * 60);
      expect(state.totalSeconds, 25 * 60);
      expect(state.progress, 0.0);
      expect(state.formattedTime, '25:00');
      expect(state.isWorkPhase, isTrue);
      expect(state.isBreakPhase, isFalse);

      // Halfway elapsed
      final halfState = state.copyWith(remainingSeconds: 12 * 60 + 30);
      expect(halfState.progress, closeTo(0.5, 0.01));
      expect(halfState.formattedTime, '12:30');
    });

    test('PomodoroTimerNotifier start, pause, distraction counter, and task linking', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pomodoroTimerProvider.notifier);
      expect(container.read(pomodoroTimerProvider).isRunning, isFalse);

      // Start timer
      notifier.start();
      expect(container.read(pomodoroTimerProvider).isRunning, isTrue);
      expect(container.read(pomodoroTimerProvider).targetEndTime, isNotNull);

      // Pause timer
      notifier.pause();
      expect(container.read(pomodoroTimerProvider).isRunning, isFalse);

      // Link Task
      notifier.setSelectedTask('task_123', 'Finish Math Homework');
      expect(
        container.read(pomodoroTimerProvider).selectedTaskId,
        'task_123',
      );
      expect(
        container.read(pomodoroTimerProvider).selectedTaskTitle,
        'Finish Math Homework',
      );

      // Increment Distractions
      expect(container.read(pomodoroTimerProvider).distractionCount, 0);
      notifier.incrementDistraction();
      expect(container.read(pomodoroTimerProvider).distractionCount, 1);
      notifier.incrementDistraction();
      expect(container.read(pomodoroTimerProvider).distractionCount, 2);
    });

    test('PomodoroTimerNotifier phase transitions and 4-session long break cycle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pomodoroTimerProvider.notifier);

      // 1. First Work session skipped -> Short Break (cycle count = 1)
      notifier.skip();
      var state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.completedSessionsInCycle, 1);
      expect(state.remainingSeconds, 5 * 60);

      // 2. Short Break skipped -> Work session (cycle count = 1)
      notifier.skip();
      state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.work);
      expect(state.completedSessionsInCycle, 1);

      // 3. Second Work session skipped -> Short Break (cycle count = 2)
      notifier.skip();
      state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.completedSessionsInCycle, 2);

      // 4. Short Break skipped -> Work session (cycle count = 2)
      notifier.skip();

      // 5. Third Work session skipped -> Short Break (cycle count = 3)
      notifier.skip();
      state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.shortBreak);
      expect(state.completedSessionsInCycle, 3);

      // 6. Short Break skipped -> Work session (cycle count = 3)
      notifier.skip();

      // 7. Fourth Work session skipped -> Long Break (cycle count resets to 0)
      notifier.skip();
      state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.longBreak);
      expect(state.completedSessionsInCycle, 0);
      expect(state.remainingSeconds, 15 * 60);

      // 8. Long Break skipped -> Work session
      notifier.skip();
      state = container.read(pomodoroTimerProvider);
      expect(state.phase, PomodoroPhase.work);
    });

    test('PomodoroTimerNotifier updateConfig updates durations correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(pomodoroTimerProvider.notifier);

      const customConfig = PomodoroConfig(
        workMinutes: 50,
        shortBreakMinutes: 10,
        longBreakMinutes: 30,
        longBreakInterval: 2,
        autoStartNext: true,
      );

      notifier.updateConfig(customConfig);
      final state = container.read(pomodoroTimerProvider);

      expect(state.config.workMinutes, 50);
      expect(state.remainingSeconds, 50 * 60);
      expect(state.totalSeconds, 50 * 60);
      expect(state.formattedTime, '50:00');
    });
  });
}
