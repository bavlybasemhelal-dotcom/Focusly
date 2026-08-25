import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/habits/providers/habits_provider.dart';
import 'package:focusly/features/pdf_reports/helpers/report_data_aggregator.dart';
import 'package:focusly/features/pdf_reports/helpers/report_pdf_builder.dart';
import 'package:focusly/features/pdf_reports/models/report_models.dart';
import 'package:focusly/features/pdf_reports/report_range_page.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_log_model.dart';
import 'package:focusly/features/pomodoro/providers/pomodoro_provider.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/schedule/models/event_model.dart';
import 'package:focusly/features/schedule/providers/schedule_provider.dart';
import 'package:focusly/features/tasks/models/category_model.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createPdfReportTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_pdf'),
      tasksStreamProvider.overrideWith((ref) => Stream.value([])),
      eventsStreamProvider.overrideWith((ref) => Stream.value([])),
      habitsStreamProvider.overrideWith((ref) => Stream.value([])),
      pomodoroLogsStreamProvider.overrideWith((ref) => Stream.value([])),
      categoriesProvider.overrideWith((ref) => Stream.value(TaskCategory.defaultCategories)),
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
  group('ReportDataAggregator Pure Math & Scaling Tests', () {
    final refDate = DateTime(2026, 8, 25);

    test('Weekly target scaling and score tiers (7 days)', () {
      // Weekly targets: tasks=12, focus=300m, habits=14
      // 12 tasks (100%), 300 focus minutes (100%), 14 habit days (100%)
      final scoreIncredible = ReportDataAggregator.computeProductivityScore(
        completedTasks: 12,
        totalFocusMinutes: 300,
        habitDaysLogged: 14,
        daysCount: 7,
      );

      expect(scoreIncredible.taskScore, equals(100));
      expect(scoreIncredible.focusScore, equals(100));
      expect(scoreIncredible.habitsScore, equals(100));
      expect(scoreIncredible.overallScore, equals(100));
      expect(scoreIncredible.tierKey, equals('score_tier_incredible'));
      expect(scoreIncredible.tierColorHex, equals(0xFF10B981));

      // 6 tasks (50%), 150m focus (50%), 7 habit days (50%) -> overall 50%
      final scoreBalanced = ReportDataAggregator.computeProductivityScore(
        completedTasks: 6,
        totalFocusMinutes: 150,
        habitDaysLogged: 7,
        daysCount: 7,
      );
      expect(scoreBalanced.overallScore, equals(50));
      expect(scoreBalanced.tierKey, equals('score_tier_balanced'));
      expect(scoreBalanced.tierColorHex, equals(0xFFF59E0B));

      // 1 task (8%), 30m (10%), 1 habit day (7%) -> overall ~8%
      final scoreNeedsFocus = ReportDataAggregator.computeProductivityScore(
        completedTasks: 1,
        totalFocusMinutes: 30,
        habitDaysLogged: 1,
        daysCount: 7,
      );
      expect(scoreNeedsFocus.overallScore, lessThan(25));
      expect(scoreNeedsFocus.tierKey, equals('score_tier_needs_focus'));
      expect(scoreNeedsFocus.tierColorHex, equals(0xFFEF4444));
    });

    test('Monthly target scaling (30 days)', () {
      // Monthly targets: tasks = 30 * 1.5 = 45, focus = 30 * 40 = 1200m, habits = 30 * 2 = 60
      final score = ReportDataAggregator.computeProductivityScore(
        completedTasks: 36, // 36 / 45 = 80%
        totalFocusMinutes: 960, // 960 / 1200 = 80%
        habitDaysLogged: 48, // 48 / 60 = 80%
        daysCount: 30,
      );

      expect(score.taskScore, equals(80));
      expect(score.focusScore, equals(80));
      expect(score.habitsScore, equals(80));
      expect(score.overallScore, equals(80));
      expect(score.tierKey, equals('score_tier_excellent'));
      expect(score.tierColorHex, equals(0xFF06B6D4));
    });

    test('aggregateReportData collects tasks, events, categories, and trends accurately', () {
      final tasks = [
        TaskModel(
          id: 't1',
          title: 'Work task 1',
          categoryId: 'work',
          date: DateTime(2026, 8, 24),
          done: true,
          doneAt: DateTime(2026, 8, 24),
          createdAt: DateTime(2026, 8, 24),
        ),
        TaskModel(
          id: 't2',
          title: 'Work task 2',
          categoryId: 'work',
          date: DateTime(2026, 8, 25),
          done: true,
          doneAt: DateTime(2026, 8, 25),
          createdAt: DateTime(2026, 8, 25),
        ),
        TaskModel(
          id: 't3',
          title: 'Personal task',
          categoryId: 'personal',
          date: DateTime(2026, 8, 25),
          done: true,
          doneAt: DateTime(2026, 8, 25),
          createdAt: DateTime(2026, 8, 25),
        ),
        TaskModel(
          id: 't4',
          title: 'Pending task',
          categoryId: 'work',
          date: DateTime(2026, 8, 25),
          done: false,
          createdAt: DateTime(2026, 8, 25),
        ),
      ];

      final events = <EventModel>[
        EventModel(
          id: 'e1',
          title: 'Meeting',
          date: DateTime(2026, 8, 24),
          time: const TimeOfDay(hour: 10, minute: 0),
          typeId: 'work',
          createdAt: refDate,
        ),
      ];

      final habits = [
        HabitModel(
          id: 'h1',
          title: 'Workout',
          days: [true, true, true, true, false, false, false], // 4 checked
          createdAt: refDate,
        ),
      ];

      final pomodoroLogs = [
        PomodoroLogModel(
          id: 'p1',
          date: DateTime(2026, 8, 25),
          taskTitle: 'Work Session',
          durationMinutes: 50,
          durationSeconds: 3000,
          distractionCount: 2,
          createdAt: refDate,
        ),
        PomodoroLogModel(
          id: 'p2',
          date: DateTime(2026, 8, 24),
          taskTitle: 'Study Session',
          durationMinutes: 25,
          durationSeconds: 1500,
          distractionCount: 0,
          createdAt: refDate,
        ),
      ];

      final data = ReportDataAggregator.aggregateReportData(
        rangeOption: ReportRangeOption.weekly,
        tasks: tasks,
        events: events,
        habits: habits,
        pomodoroLogs: pomodoroLogs,
        categories: TaskCategory.defaultCategories,
        referenceDate: refDate,
      );

      expect(data.completedTasksCount, equals(3));
      expect(data.pendingTasksCount, equals(1));
      expect(data.totalTasksCount, equals(4));
      expect(data.completionRatePercent, equals(75)); // 3/4
      expect(data.eventsCount, equals(1));
      expect(data.habitDaysLogged, equals(4));
      expect(data.totalFocusMinutes, equals(75));
      expect(data.formattedFocusTime, equals('1h 15m'));
      expect(data.avgDistractionsPerSession, equals(1.0)); // (2+0)/2

      // Category breakdown: 2 work (66.7%), 1 personal (33.3%)
      expect(data.categoryStats.length, equals(2));
      final workStat = data.categoryStats.firstWhere((s) => s.categoryId == 'work');
      expect(workStat.count, equals(2));
      expect(workStat.percentage, equals(66.7));

      // Trend points length for weekly = 7 days
      expect(data.trendPoints.length, equals(7));
    });
  });

  group('PDF Builder Tests', () {
    testWidgets('ReportPdfBuilder builds valid PDF document buffer', (tester) async {
      late AppLocalizations localizations;

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              localizations = AppLocalizations.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dummyData = ReportDataAggregator.aggregateReportData(
        rangeOption: ReportRangeOption.weekly,
        tasks: [],
        events: [],
        habits: [],
        pomodoroLogs: [],
        referenceDate: DateTime(2026, 8, 25),
      );

      final pdfBytes = await ReportPdfBuilder.buildReportPdf(
        data: dummyData,
        localizations: localizations,
        isArabic: false,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });

  group('PDF Reports UI & Widget Tests', () {
    testWidgets('ReportRangePage renders 4 range selection cards and generate button', (tester) async {
      await tester.pumpWidget(
        createPdfReportTestWidget(
          child: const ReportRangePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PDF Reports'), findsOneWidget);
      expect(find.text('Select Report Range'), findsOneWidget);
      expect(find.text('Weekly (Last 7 Days)'), findsOneWidget);
      expect(find.text('Monthly (Last 30 Days)'), findsOneWidget);
      expect(find.text('Semi-Annual (Last 180 Days)'), findsOneWidget);
      expect(find.text('Annual (Last 365 Days)'), findsOneWidget);
      expect(find.text('Generate PDF Report'), findsOneWidget);

      // Tap Monthly card to switch range
      await tester.tap(find.text('Monthly (Last 30 Days)'));
      await tester.pumpAndSettle();

      expect(find.text('30 days aggregated analysis'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains PDF Reports under Analytics section', (tester) async {
      await tester.pumpWidget(
        createPdfReportTestWidget(
          child: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('PDF Reports'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all PDF Reports texts', (tester) async {
      await tester.pumpWidget(
        createPdfReportTestWidget(
          locale: const Locale('ar'),
          child: const ReportRangePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تقارير PDF'), findsOneWidget);
      expect(find.text('اختر الفترة الزمنية للتقرير'), findsOneWidget);
      expect(find.text('أسبوعي (آخر ٧ أيام)'), findsOneWidget);
      expect(find.text('شهري (آخر ٣٠ يوماً)'), findsOneWidget);
      expect(find.text('إنشاء تقرير PDF'), findsOneWidget);
    });
  });
}
