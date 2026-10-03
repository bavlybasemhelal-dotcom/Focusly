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
import 'package:focusly/features/life_analytics/helpers/life_analytics_helpers.dart';
import 'package:focusly/features/life_analytics/life_analytics_page.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createAnalyticsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_analytics'),
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
  group('LifeAnalyticsHelpers Unit Tests', () {
    final now = DateTime.now();

    final mockCheckins = [
      // Day 1: High energy (5) - 3 tasks completed
      CheckinModel(
        date: '2026-08-25',
        energy: 5,
        mood: '🤩',
        createdAt: now,
        updatedAt: now,
      ),
      // Day 2: High energy (4) - 1 task completed
      CheckinModel(
        date: '2026-08-24',
        energy: 4,
        mood: '😊',
        createdAt: now,
        updatedAt: now,
      ),
      // Day 3: Low energy (2) - 0 tasks completed
      CheckinModel(
        date: '2026-08-23',
        energy: 2,
        mood: '😐',
        createdAt: now,
        updatedAt: now,
      ),
      // Day 4: Low energy (1) - 1 task completed
      CheckinModel(
        date: '2026-08-22',
        energy: 1,
        mood: '😞',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final mockTasks = [
      // 3 tasks on 2026-08-25 (Tuesday)
      TaskModel(
        id: 't1',
        title: 'Task 1',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: true,
        doneAt: DateTime(2026, 8, 25, 10, 0),
        createdAt: now,
      ),
      TaskModel(
        id: 't2',
        title: 'Task 2',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: true,
        doneAt: DateTime(2026, 8, 25, 14, 0),
        createdAt: now,
      ),
      TaskModel(
        id: 't3',
        title: 'Task 3',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: true,
        doneAt: DateTime(2026, 8, 25, 17, 0),
        createdAt: now,
      ),
      // 1 task on 2026-08-24 (Monday)
      TaskModel(
        id: 't4',
        title: 'Task 4',
        categoryId: 'personal',
        date: DateTime(2026, 8, 24),
        done: true,
        doneAt: DateTime(2026, 8, 24, 11, 0),
        createdAt: now,
      ),
      // 1 task on 2026-08-22 (Saturday)
      TaskModel(
        id: 't5',
        title: 'Task 5',
        categoryId: 'personal',
        date: DateTime(2026, 8, 22),
        done: true,
        doneAt: DateTime(2026, 8, 22, 16, 0),
        createdAt: now,
      ),
      // Incomplete task
      TaskModel(
        id: 't6',
        title: 'Task 6',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: false,
        createdAt: now,
      ),
    ];

    test('computeEnergyProductivityImpact calculates avgHigh and avgLow accurately', () {
      final impact = LifeAnalyticsHelpers.computeEnergyProductivityImpact(
        checkins: mockCheckins,
        tasks: mockTasks,
      );

      // High energy days (2026-08-25: 3 tasks, 2026-08-24: 1 task) -> total 4 tasks / 2 days = 2.0
      expect(impact.highDaysCount, equals(2));
      expect(impact.avgHigh, equals(2.0));
      expect(impact.formattedAvgHigh, equals('2.0'));

      // Low energy days (2026-08-23: 0 tasks, 2026-08-22: 1 task) -> total 1 task / 2 days = 0.5
      expect(impact.lowDaysCount, equals(2));
      expect(impact.avgLow, equals(0.5));
      expect(impact.formattedAvgLow, equals('0.5'));
    });

    test('computeMostProductiveDay finds day of week with highest completed tasks', () {
      final result = LifeAnalyticsHelpers.computeMostProductiveDay(mockTasks);

      expect(result.hasCompletedTasks, isTrue);
      // Tuesday (2026-08-25) had 3 tasks completed
      expect(result.dayOfWeek, equals(DateTime.tuesday));
      expect(result.dayNameKey, equals('day_tuesday'));
      expect(result.completedTasksCount, equals(3));
    });

    test('computeMostProductiveDay handles empty tasks gracefully', () {
      final result = LifeAnalyticsHelpers.computeMostProductiveDay([]);

      expect(result.hasCompletedTasks, isFalse);
      expect(result.completedTasksCount, equals(0));
    });
  });

  group('TaskModel doneAt Tests', () {
    test('TaskModel serializes and deserializes doneAt accurately', () {
      final now = DateTime(2026, 8, 25, 15, 30);
      final task = TaskModel(
        id: 'task_1',
        title: 'Test task',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: true,
        doneAt: now,
        createdAt: now,
      );

      final map = task.toMap();
      expect(map['doneAt'], isA<Timestamp>());

      final deserialized = TaskModel.fromMap(map, 'task_1');
      expect(deserialized.id, equals('task_1'));
      expect(deserialized.done, isTrue);
      expect(deserialized.doneAt, isNotNull);
      expect(deserialized.doneAt!.year, equals(2026));
    });
  });

  group('Life Analytics UI & Widget Tests', () {
    final now = DateTime.now();
    final mockCheckins = [
      CheckinModel(
        date: '2026-08-25',
        energy: 5,
        mood: '🤩',
        createdAt: now,
        updatedAt: now,
      ),
      CheckinModel(
        date: '2026-08-24',
        energy: 2,
        mood: '😞',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final mockTasks = [
      TaskModel(
        id: '1',
        title: 'Completed work',
        categoryId: 'work',
        date: DateTime(2026, 8, 25),
        done: true,
        doneAt: DateTime(2026, 8, 25, 12, 0),
        createdAt: now,
      ),
    ];

    testWidgets('LifeAnalyticsPage renders empty state when zero check-ins exist', (tester) async {
      await tester.pumpWidget(
        createAnalyticsTestWidget(
          child: const LifeAnalyticsPage(),
          overrides: [
            checkinsHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            tasksStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧬 Start logging your energy daily to see analytics'), findsOneWidget);
      expect(find.text('Go to Energy Page'), findsOneWidget);
    });

    testWidgets('LifeAnalyticsPage renders Energy Impact and Most Productive Day cards', (tester) async {
      await tester.pumpWidget(
        createAnalyticsTestWidget(
          child: const LifeAnalyticsPage(),
          overrides: [
            checkinsHistoryStreamProvider.overrideWith((ref) => Stream.value(mockCheckins)),
            tasksStreamProvider.overrideWith((ref) => Stream.value(mockTasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Energy Impact Card
      expect(find.text('Energy Impact on Productivity'), findsOneWidget);
      expect(find.text('Avg Tasks (High Energy ≥ 4)'), findsOneWidget);
      expect(find.text('Avg Tasks (Low Energy ≤ 2)'), findsOneWidget);
      expect(find.text('1.0'), findsOneWidget); // avgHigh
      expect(find.text('0.0'), findsOneWidget); // avgLow
      expect(find.text('Keeping your energy high directly correlates to higher output'), findsOneWidget);

      // Most Productive Day Card
      expect(find.text('Most Productive Day'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('With 1 tasks completed on this day of the week'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains Analytics section with Life Analytics item', (tester) async {
      await tester.pumpWidget(
        createAnalyticsTestWidget(
          child: const HomeScreen(),
          overrides: [
            checkinsHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            tasksStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('Life Analytics'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Life Analytics texts', (tester) async {
      await tester.pumpWidget(
        createAnalyticsTestWidget(
          locale: const Locale('ar'),
          child: const LifeAnalyticsPage(),
          overrides: [
            checkinsHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
            tasksStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تحليلات الحياة'), findsOneWidget);
      expect(find.text('🧬 ابدأ بتسجيل مستوى طاقتك اليومي لعرض التحليلات'), findsOneWidget);
      expect(find.text('الانتقال إلى صفحة الطاقة'), findsOneWidget);
    });
  });
}
