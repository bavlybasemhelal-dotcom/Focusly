import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/workout_tracker/helpers/workout_helpers.dart';
import 'package:focusly/features/workout_tracker/models/workout_model.dart';
import 'package:focusly/features/workout_tracker/providers/workout_provider.dart';
import 'package:focusly/features/workout_tracker/widgets/workout_card.dart';
import 'package:focusly/features/workout_tracker/widgets/workout_form_modal.dart';
import 'package:focusly/features/workout_tracker/widgets/workout_heatmap_widget.dart';
import 'package:focusly/features/workout_tracker/workout_tracker_page.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createWorkoutTrackerTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_workouts'),
      morningIntentionPromptSettingProvider.overrideWith(
        MorningIntentionPromptSettingNotifier.new,
      ),
      morningIntentionDismissedProvider.overrideWith(MockDismissedNotifier.new),
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
      home: child,
    ),
  );
}

void main() {
  group('Workout Tracker Pure Helper & Calculation Tests', () {
    final now = DateTime(2026, 8, 24);

    test('calculateStats aggregates only workouts within the past 7 days', () {
      final workouts = [
        WorkoutModel(
          id: '1',
          type: 'gym',
          durationMin: 60,
          calories: 450,
          date: DateTime(2026, 8, 24), // Today
          createdAt: now,
          updatedAt: now,
        ),
        WorkoutModel(
          id: '2',
          type: 'running',
          durationMin: 30,
          calories: 300,
          date: DateTime(2026, 8, 21), // 3 days ago
          createdAt: now,
          updatedAt: now,
        ),
        WorkoutModel(
          id: '3',
          type: 'swim',
          durationMin: 45,
          calories: 400,
          date: DateTime(2026, 8, 10), // 14 days ago (outside 7-day window)
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final stats = WorkoutHelpers.calculateStats(workouts, now);
      // Minutes: 60 + 30 = 90. Calories: 450 + 300 = 750. Total: 3
      expect(stats.thisWeekMinutes, equals(90));
      expect(stats.thisWeekCalories, equals(750));
      expect(stats.totalWorkoutsCount, equals(3));
    });

    test(
      'compute30DayHeatmap generates 30 days and accurately flags active workout days',
      () {
        final workouts = [
          WorkoutModel(
            id: '1',
            type: 'gym',
            durationMin: 50,
            calories: 400,
            date: DateTime(2026, 8, 24), // Today (index 29)
            createdAt: now,
            updatedAt: now,
          ),
          WorkoutModel(
            id: '2',
            type: 'yoga',
            durationMin: 30,
            calories: 120,
            date: DateTime(2026, 8, 24), // Second workout today
            createdAt: now,
            updatedAt: now,
          ),
          WorkoutModel(
            id: '3',
            type: 'running',
            durationMin: 25,
            calories: 250,
            date: DateTime(2026, 8, 23), // Yesterday (index 28)
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final heatmap = WorkoutHelpers.compute30DayHeatmap(workouts, now);
        expect(heatmap.length, equals(30));

        final todayDay = heatmap[29];
        expect(todayDay.hasWorkout, isTrue);
        expect(todayDay.workoutCount, equals(2));
        expect(todayDay.totalDurationMin, equals(80)); // 50 + 30
        expect(todayDay.totalCalories, equals(520)); // 400 + 120

        final yesterdayDay = heatmap[28];
        expect(yesterdayDay.hasWorkout, isTrue);
        expect(yesterdayDay.workoutCount, equals(1));

        final restDay = heatmap[20];
        expect(restDay.hasWorkout, isFalse);
        expect(restDay.workoutCount, equals(0));
      },
    );
  });

  group('WorkoutModel Serialization Tests', () {
    test(
      'WorkoutModel serializes toMap and deserializes fromMap correctly',
      () {
        final now = DateTime(2026, 8, 24, 14, 0);
        final workout = WorkoutModel(
          id: 'w_1',
          type: 'running',
          durationMin: 45,
          calories: 420,
          date: DateTime(2026, 8, 24),
          note: 'Morning trail run in the park.',
          createdAt: now,
          updatedAt: now,
        );

        final map = workout.toMap();
        expect(map['type'], equals('running'));
        expect(map['durationMin'], equals(45));
        expect(map['calories'], equals(420));
        expect(map['note'], equals('Morning trail run in the park.'));

        final reconstructed = WorkoutModel.fromMap(map, 'w_1');
        expect(reconstructed.id, equals('w_1'));
        expect(reconstructed.type, equals('running'));
        expect(reconstructed.durationMin, equals(45));
        expect(reconstructed.calories, equals(420));
        expect(reconstructed.note, contains('trail run'));
      },
    );
  });

  group('Workout Tracker UI & Widget Tests', () {
    testWidgets(
      'WorkoutCard renders workout type, duration, date, note, and calories badge',
      (tester) async {
        final now = DateTime.now();
        final workout = WorkoutModel(
          id: 'w1',
          type: 'gym',
          durationMin: 60,
          calories: 500,
          date: now,
          note: 'Chest and triceps heavy day.',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createWorkoutTrackerTestWidget(
            child: Scaffold(body: WorkoutCard(workout: workout)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Gym / Weights'), findsOneWidget);
        expect(find.text('60 min'), findsOneWidget);
        expect(find.text('500 kcal'), findsOneWidget);
        expect(find.text('Chest and triceps heavy day.'), findsOneWidget);
        expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
      },
    );

    testWidgets('WorkoutHeatmapWidget renders 30 cells in grid', (
      tester,
    ) async {
      final now = DateTime.now();
      final workout = WorkoutModel(
        id: 'w1',
        type: 'running',
        durationMin: 30,
        calories: 300,
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createWorkoutTrackerTestWidget(
          child: const Scaffold(body: WorkoutHeatmapWidget()),
          overrides: [
            workoutsStreamProvider.overrideWithValue(AsyncData([workout])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last 30 Days Streak'), findsOneWidget);
      expect(find.text('1 / 30 days'), findsOneWidget);
    });

    testWidgets('WorkoutFormModal validates duration greater than 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWorkoutTrackerTestWidget(
          child: const Scaffold(body: WorkoutFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Workout Session'), findsOneWidget);

      // Enter 0 for duration
      final durationField = find.widgetWithText(TextField, '45');
      await tester.enterText(durationField, '0');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Duration must be greater than 0'), findsOneWidget);
    });

    testWidgets(
      'WorkoutTrackerPage renders stats row, heatmap, and empty state',
      (tester) async {
        await tester.pumpWidget(
          createWorkoutTrackerTestWidget(
            child: const WorkoutTrackerPage(),
            overrides: [
              workoutsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Workout Tracker'), findsOneWidget);
        expect(find.text('This Week Minutes'), findsOneWidget);
        expect(find.text('This Week Calories'), findsOneWidget);
        expect(find.text('Recent Workouts'), findsOneWidget);
        expect(find.text('Last 30 Days Streak'), findsOneWidget);
        expect(
          find.text('💪 Start by logging your first workout'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Navigation Drawer contains Workout Tracker item in Health section',
      (tester) async {
        await tester.pumpWidget(
          createWorkoutTrackerTestWidget(
            child: const HomeScreen(),
            overrides: [
              workoutsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open Navigation Drawer
        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Scroll inside drawer to find "Workout Tracker"
        final drawerScrollable = find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Workout Tracker'),
          50,
          scrollable: drawerScrollable,
        );
        expect(find.text('Workout Tracker'), findsOneWidget);
      },
    );
  });
}
