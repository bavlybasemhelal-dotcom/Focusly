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

    test(
      'PomodoroTimerNotifier start, pause, distraction counter, and task linking',
      () {
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
      },
    );

    test('Skipping never counts as a completed work session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(pomodoroTimerProvider.notifier);
      for (var i = 0; i < 8; i++) {
        notifier.skip();
        expect(
          container.read(pomodoroTimerProvider).phase,
          PomodoroPhase.shortBreak,
        );
        expect(
          container.read(pomodoroTimerProvider).completedSessionsInCycle,
          0,
        );
        notifier.skip();
        expect(container.read(pomodoroTimerProvider).phase, PomodoroPhase.work);
      }
    });

    testWidgets('Four actually completed countdowns earn a long break', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 3, 9);
      final container = ProviderContainer(
        overrides: [pomodoroNowProvider.overrideWithValue(() => now)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(pomodoroTimerProvider.notifier);
      for (var i = 1; i <= 4; i++) {
        notifier.start();
        now = now.add(const Duration(minutes: 25));
        await tester.pump(const Duration(seconds: 1));
        final state = container.read(pomodoroTimerProvider);
        expect(
          state.phase,
          i == 4 ? PomodoroPhase.longBreak : PomodoroPhase.shortBreak,
        );
        expect(state.completedSessionsInCycle, i == 4 ? 0 : i);
        notifier.skip();
      }
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
