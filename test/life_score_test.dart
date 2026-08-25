import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/energy_mood/models/checkin_model.dart';
import 'package:focusly/features/energy_mood/providers/energy_mood_provider.dart';
import 'package:focusly/features/goals/models/goal_model.dart';
import 'package:focusly/features/goals/providers/goals_provider.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/habits/providers/habits_provider.dart';
import 'package:focusly/features/life_score/helpers/life_score_calculator.dart';
import 'package:focusly/features/life_score/life_score_detail_page.dart';
import 'package:focusly/features/life_score/models/life_score_model.dart';
import 'package:focusly/features/life_score/providers/life_score_provider.dart';
import 'package:focusly/features/life_score/widgets/life_score_widget.dart';
import 'package:focusly/features/reading_tracker/models/book_model.dart';
import 'package:focusly/features/reading_tracker/providers/reading_provider.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

class MockSelectedWeekNotifier extends SelectedWeekNotifier {
  final DateTime initialWeek;
  MockSelectedWeekNotifier(this.initialWeek);
  @override
  DateTime build() => initialWeek;
}

Widget createLifeScoreTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_life_score'),
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
  group('LifeScoreCalculator Pure Math Tests', () {
    final weekStart = DateTime(2026, 8, 23); // Sunday
    final now = DateTime(2026, 8, 25);

    test('Tasks scoring: 30% weight with ratio, capping, and edge cases', () {
      final tasks = [
        TaskModel(
          id: 't1',
          title: 'T1',
          categoryId: 'work',
          date: DateTime(2026, 8, 24),
          done: true,
          doneAt: DateTime(2026, 8, 24),
          createdAt: DateTime(2026, 8, 24),
        ),
        TaskModel(
          id: 't2',
          title: 'T2',
          categoryId: 'work',
          date: DateTime(2026, 8, 25),
          done: false,
          createdAt: DateTime(2026, 8, 25),
        ),
      ];

      // 1 done out of 2 created/dated = 50%
      final score = LifeScoreCalculator.computeLifeScore(
        weekStart: weekStart,
        tasks: tasks,
        habits: [],
        checkins: [],
        books: [],
        goals: [],
      );

      expect(score.breakdown.tasks, equals(50.0));
      expect(score.breakdown.tasksContribution, equals(15.0)); // 50 * 0.30
    });

    test('Habits scoring: live calculation for current week vs snapshot for past weeks', () {
      final habit1 = HabitModel(
        id: 'h1',
        title: 'Exercise',
        days: [true, true, true, false, false, false, false], // 3 days
        createdAt: now,
      );
      final habit2 = HabitModel(
        id: 'h2',
        title: 'Meditation',
        days: [true, true, true, true, false, false, false], // 4 days
        createdAt: now,
      );

      // Current week live: (7 total checked / 14 possible) * 100 = 50.0%
      final liveScore = LifeScoreCalculator.computeLifeScore(
        weekStart: weekStart,
        tasks: [],
        habits: [habit1, habit2],
        checkins: [],
        books: [],
        goals: [],
        isCurrentWeek: true,
      );
      expect(liveScore.breakdown.habits, equals(50.0));
      expect(liveScore.breakdown.habitsContribution, equals(12.5)); // 50 * 0.25

      // Past week: reads from pastWeekSnapshot
      final pastSnapshot = LifeScoreModel(
        id: '2026-08-16',
        weekOf: '2026-08-16',
        total: 75,
        breakdown: const ScoreBreakdown(habits: 80.0),
        computedAt: DateTime(2026, 8, 22),
      );

      final pastScore = LifeScoreCalculator.computeLifeScore(
        weekStart: DateTime(2026, 8, 16),
        tasks: [],
        habits: [habit1, habit2], // Even if current habit days differ
        checkins: [],
        books: [],
        goals: [],
        pastWeekSnapshot: pastSnapshot,
        isCurrentWeek: false,
      );
      expect(pastScore.breakdown.habits, equals(80.0));
      expect(pastScore.breakdown.habitsContribution, equals(20.0)); // 80 * 0.25
    });

    test('Energy (15%), Learning (10%), Checkins (10%), Goals (10%) calculations', () {
      // 3 check-ins with energy 4, 5, 3 (avg = 4.0 / 5.0 * 100 = 80.0%)
      final checkins = [
        CheckinModel(
          date: '2026-08-23',
          energy: 4,
          mood: '😊',
          createdAt: now,
          updatedAt: now,
        ),
        CheckinModel(
          date: '2026-08-24',
          energy: 5,
          mood: '🤩',
          createdAt: now,
          updatedAt: now,
        ),
        CheckinModel(
          date: '2026-08-25',
          energy: 3,
          mood: '😐',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // 2 books finished that week (2 * 25 = 50.0%)
      final books = [
        BookModel(
          id: 'b1',
          title: 'Deep Work',
          author: 'Cal Newport',
          status: 'done',
          finishDate: DateTime(2026, 8, 24),
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: 'b2',
          title: 'Atomic Habits',
          author: 'James Clear',
          status: 'done',
          finishDate: DateTime(2026, 8, 25),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      // Active goals with progress 60% and 80% (avg = 70.0%)
      final goals = [
        GoalModel(
          id: 'g1',
          title: 'Goal 1',
          progress: 60,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
        GoalModel(
          id: 'g2',
          title: 'Goal 2',
          progress: 80,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
        GoalModel(
          id: 'g3',
          title: 'Completed Goal (ignored)',
          progress: 100,
          status: 'done',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final score = LifeScoreCalculator.computeLifeScore(
        weekStart: weekStart,
        tasks: [],
        habits: [],
        checkins: checkins,
        books: books,
        goals: goals,
      );

      // Energy: 80.0 -> Contribution = 80 * 0.15 = 12.0
      expect(score.breakdown.energy, equals(80.0));
      expect(score.breakdown.energyContribution, equals(12.0));

      // Learning: 50.0 -> Contribution = 50 * 0.10 = 5.0
      expect(score.breakdown.learning, equals(50.0));
      expect(score.breakdown.learningContribution, equals(5.0));

      // Check-ins: 3 distinct days / 7 = 42.9% -> Contribution = 4.3
      expect(score.breakdown.checkins, closeTo(42.9, 0.1));
      expect(score.breakdown.checkinsContribution, closeTo(4.3, 0.1));

      // Goals: 70.0 -> Contribution = 70 * 0.10 = 7.0
      expect(score.breakdown.goals, equals(70.0));
      expect(score.breakdown.goalsContribution, equals(7.0));
    });
  });

  group('Life Score Models Serialization Tests', () {
    test('ScoreBreakdown and LifeScoreModel serialize and deserialize accurately', () {
      const breakdown = ScoreBreakdown(
        tasks: 90.0,
        habits: 80.0,
        energy: 85.0,
        learning: 75.0,
        checkins: 100.0,
        goals: 65.0,
      );

      final now = DateTime(2026, 8, 25, 10, 0);
      final model = LifeScoreModel(
        id: '2026-08-23',
        weekOf: '2026-08-23',
        total: 83,
        breakdown: breakdown,
        computedAt: now,
      );

      expect(model.qualitativeKey, equals('life_score_excellent'));
      expect(model.tierColor, equals(const Color(0xFF10B981)));

      final map = model.toMap();
      expect(map['weekOf'], equals('2026-08-23'));
      expect(map['total'], equals(83));
      expect(map['breakdown']['tasks'], equals(90.0));
      expect(map['computedAt'], isA<Timestamp>());

      final deserialized = LifeScoreModel.fromMap(map, '2026-08-23');
      expect(deserialized.id, equals('2026-08-23'));
      expect(deserialized.total, equals(83));
      expect(deserialized.breakdown.habits, equals(80.0));
      expect(deserialized.breakdown.checkins, equals(100.0));
    });
  });

  group('Life Score UI & Widget Tests', () {
    final weekStart = DateTime(2026, 8, 23);
    final now = DateTime(2026, 8, 25);

    final mockScore = LifeScoreModel(
      id: '2026-08-23',
      weekOf: '2026-08-23',
      total: 82,
      breakdown: const ScoreBreakdown(
        tasks: 80.0,
        habits: 75.0,
        energy: 85.0,
        learning: 100.0,
        checkins: 90.0,
        goals: 70.0,
      ),
      computedAt: now,
    );

    testWidgets('LifeScoreWidget renders circular score and qualitative label', (tester) async {
      await tester.pumpWidget(
        createLifeScoreTestWidget(
          child: const LifeScoreWidget(),
          overrides: [
            currentLiveLifeScoreProvider.overrideWithValue(mockScore),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('82'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('Weekly Life Score'), findsOneWidget);
      expect(find.text('Excellent Week 🌟'), findsOneWidget);
    });

    testWidgets('LifeScoreDetailPage displays breakdown table with all 6 categories and total row', (tester) async {
      await tester.pumpWidget(
        createLifeScoreTestWidget(
          child: const LifeScoreDetailPage(),
          overrides: [
            currentWeekStartProvider.overrideWithValue(weekStart),
            selectedWeekStartProvider.overrideWith(
              () => MockSelectedWeekNotifier(weekStart),
            ),
            selectedWeekLifeScoreProvider.overrideWithValue(mockScore),
            lifeScoreLogsStreamProvider.overrideWith((ref) => Stream.value([mockScore])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Gauge and qualitative badge
      expect(find.text('82'), findsOneWidget);
      expect(find.text('Excellent Week 🌟'), findsOneWidget);

      // 6 Category rows
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Habits'), findsOneWidget);
      expect(find.text('Energy Level'), findsOneWidget);
      expect(find.text('Learning (Reading)'), findsOneWidget);
      expect(find.text('Daily Check-ins'), findsOneWidget);
      expect(find.text('Goals Progress'), findsOneWidget);

      // Total row
      expect(find.text('Total Life Score'), findsOneWidget);
      expect(find.text('82 / 100'), findsOneWidget);
    });

    testWidgets('LifeScoreDetailPage renders empty state for past week with no snapshot', (tester) async {
      final pastWeek = DateTime(2026, 8, 9);

      await tester.pumpWidget(
        createLifeScoreTestWidget(
          child: const LifeScoreDetailPage(),
          overrides: [
            currentWeekStartProvider.overrideWithValue(weekStart),
            selectedWeekStartProvider.overrideWith(
              () => MockSelectedWeekNotifier(pastWeek),
            ),
            selectedWeekLifeScoreProvider.overrideWithValue(null),
            lifeScoreLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No data recorded for this week'), findsOneWidget);
      expect(find.text('Compute Now'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains Analytics section with Weekly Life Score item', (tester) async {
      await tester.pumpWidget(
        createLifeScoreTestWidget(
          child: const HomeScreen(),
          overrides: [
            currentLiveLifeScoreProvider.overrideWithValue(mockScore),
            lifeScoreLogsStreamProvider.overrideWith((ref) => Stream.value([mockScore])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('Weekly Life Score'), findsOneWidget);
    });

    testWidgets('Arabic localization renders Weekly Life Score breakdown and texts', (tester) async {
      await tester.pumpWidget(
        createLifeScoreTestWidget(
          locale: const Locale('ar'),
          child: const LifeScoreDetailPage(),
          overrides: [
            currentWeekStartProvider.overrideWithValue(weekStart),
            selectedWeekStartProvider.overrideWith(
              () => MockSelectedWeekNotifier(weekStart),
            ),
            selectedWeekLifeScoreProvider.overrideWithValue(mockScore),
            lifeScoreLogsStreamProvider.overrideWith((ref) => Stream.value([mockScore])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مؤشر الحياة الأسبوعي'), findsOneWidget);
      expect(find.text('المهام'), findsOneWidget);
      expect(find.text('العادات'), findsOneWidget);
      expect(find.text('التعلم والقراءة'), findsOneWidget);
      expect(find.text('إجمالي مؤشر الحياة'), findsOneWidget);
    });
  });
}
