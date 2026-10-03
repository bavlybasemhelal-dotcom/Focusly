import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/focus_mode/focus_mode_page.dart';
import 'package:focusly/features/focus_mode/providers/focus_mode_provider.dart';
import 'package:focusly/features/focus_mode/services/notification_queue.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_config_model.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_state.dart';
import 'package:focusly/features/pomodoro/pomodoro_screen.dart';
import 'package:focusly/features/pomodoro/providers/pomodoro_provider.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/screens/home_screen.dart';

Widget createFocusModeTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_focus'),
      morningIntentionPromptSettingProvider.overrideWith(
        MorningIntentionPromptSettingNotifier.new,
      ),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

class MockPomodoroTimerNotifier extends PomodoroTimerNotifier {
  final PomodoroTimerState initialState;
  MockPomodoroTimerNotifier(this.initialState);

  @override
  PomodoroTimerState build() => initialState;
}

void main() {
  group('NotificationQueue & FocusModeProvider Unit Tests', () {
    test(
      'NotificationQueue queues, reports count, and flushes callbacks',
      () async {
        final queue = NotificationQueue();
        queue.clear();
        expect(queue.hasQueuedItems, isFalse);
        expect(queue.queuedCount, equals(0));

        bool callback1Executed = false;
        bool callback2Executed = false;

        queue.queueCelebration((ctx) => callback1Executed = true);
        queue.queueCelebration((ctx) => callback2Executed = true);

        expect(queue.hasQueuedItems, isTrue);
        expect(queue.queuedCount, equals(2));

        queue.clear();
        expect(queue.hasQueuedItems, isFalse);
        expect(callback1Executed, isFalse);
        expect(callback2Executed, isFalse);
      },
    );

    test('FocusModeActiveNotifier enters, exits, and toggles state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(focusModeActiveProvider), isFalse);

      container.read(focusModeActiveProvider.notifier).enterFocusMode();
      expect(container.read(focusModeActiveProvider), isTrue);

      container.read(focusModeActiveProvider.notifier).exitFocusMode();
      expect(container.read(focusModeActiveProvider), isFalse);

      container.read(focusModeActiveProvider.notifier).setActive(true);
      expect(container.read(focusModeActiveProvider), isTrue);
    });
  });

  group('FocusModePage UI & Subtasks Checklist Tests', () {
    testWidgets(
      'FocusModePage renders header, task selector, timer ring, and controls',
      (tester) async {
        final now = DateTime.now();
        final task1 = TaskModel(
          id: 't1',
          title: 'Draft Project Specs',
          categoryId: 'work',
          priority: TaskPriority.high,
          done: false,
          date: now,
          createdAt: now,
          subtasks: const [
            SubtaskModel(id: 's1', title: 'Write outline', done: false),
            SubtaskModel(id: 's2', title: 'Add diagrams', done: true),
          ],
        );

        await tester.pumpWidget(
          createFocusModeTestWidget(
            child: const FocusModePage(),
            overrides: [
              tasksStreamProvider.overrideWithValue(AsyncData([task1])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Header verification
        expect(find.text('Focus Mode'), findsOneWidget);
        expect(find.text('Distraction-free'), findsOneWidget);

        // Task selector verification
        expect(find.text('Select Task to Focus On'), findsOneWidget);
        expect(find.text('Draft Project Specs'), findsOneWidget);
        expect(find.text('1/2'), findsOneWidget); // Subtasks indicator

        // Timer ring MM:SS and play control icon
        expect(find.text('25:00'), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'FocusModePage renders active task card and live subtasks checklist when task is linked',
      (tester) async {
        final now = DateTime.now();
        final task1 = TaskModel(
          id: 't_active',
          title: 'Build Authentication Flow',
          categoryId: 'work',
          priority: TaskPriority.high,
          done: false,
          date: now,
          createdAt: now,
          subtasks: const [
            SubtaskModel(id: 'sub_1', title: 'Setup Firebase Auth', done: true),
            SubtaskModel(id: 'sub_2', title: 'Design Login UI', done: false),
          ],
        );

        final initialTimerState =
            PomodoroTimerState.initial(const PomodoroConfig()).copyWith(
              selectedTaskId: 't_active',
              selectedTaskTitle: 'Build Authentication Flow',
            );

        await tester.pumpWidget(
          createFocusModeTestWidget(
            child: const FocusModePage(),
            overrides: [
              pomodoroTimerProvider.overrideWith(
                () => MockPomodoroTimerNotifier(initialTimerState),
              ),
              tasksStreamProvider.overrideWithValue(AsyncData([task1])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Active task card verification
        expect(find.text('Build Authentication Flow'), findsAtLeastNWidgets(1));
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('Switch Task'), findsOneWidget);

        // Subtasks checklist verification
        expect(find.text('Subtasks Checklist'), findsOneWidget);
        expect(find.text('1/2'), findsOneWidget);
        expect(find.text('Setup Firebase Auth'), findsOneWidget);
        expect(find.text('Design Login UI'), findsOneWidget);
      },
    );

    testWidgets(
      'FocusModePage displays empty state when linked task has no subtasks',
      (tester) async {
        final now = DateTime.now();
        final taskWithoutSubtasks = TaskModel(
          id: 't_simple',
          title: 'Review PR #42',
          categoryId: 'work',
          done: false,
          date: now,
          createdAt: now,
          subtasks: const [],
        );

        final initialTimerState =
            PomodoroTimerState.initial(const PomodoroConfig()).copyWith(
              selectedTaskId: 't_simple',
              selectedTaskTitle: 'Review PR #42',
            );

        await tester.pumpWidget(
          createFocusModeTestWidget(
            child: const FocusModePage(),
            overrides: [
              pomodoroTimerProvider.overrideWith(
                () => MockPomodoroTimerNotifier(initialTimerState),
              ),
              tasksStreamProvider.overrideWithValue(
                AsyncData([taskWithoutSubtasks]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review PR #42'), findsAtLeastNWidgets(1));
        expect(find.text('No subtasks yet'), findsOneWidget);
        expect(find.text('Add Subtask'), findsOneWidget);
      },
    );

    testWidgets('Exit commitment guard blocks exit when work timer is running', (
      tester,
    ) async {
      final runningWorkState = PomodoroTimerState.initial(
        const PomodoroConfig(),
      ).copyWith(isRunning: true, phase: PomodoroPhase.work);

      await tester.pumpWidget(
        createFocusModeTestWidget(
          child: const FocusModePage(),
          overrides: [
            pomodoroTimerProvider.overrideWith(
              () => MockPomodoroTimerNotifier(runningWorkState),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Close button should show lock icon
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.lock_outline_rounded));
      await tester.pump();

      // Guarded toast should be displayed
      expect(
        find.text(
          "🔒 Can't exit Focus Mode until the session ends or you pause/reset it",
        ),
        findsOneWidget,
      );
    });
  });

  group('Focus Mode Entry Points Tests', () {
    testWidgets('PomodoroScreen includes Enter Focus Mode button', (
      tester,
    ) async {
      await tester.pumpWidget(
        createFocusModeTestWidget(child: const PomodoroScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.center_focus_strong_rounded), findsOneWidget);
    });

    testWidgets('Navigation Drawer includes Focus Mode item', (tester) async {
      await tester.pumpWidget(
        createFocusModeTestWidget(
          child: const HomeScreen(),
          overrides: [
            morningIntentionDismissedProvider.overrideWith(
              MockDismissedNotifier.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Focus Mode'), findsOneWidget);
    });
  });
}
