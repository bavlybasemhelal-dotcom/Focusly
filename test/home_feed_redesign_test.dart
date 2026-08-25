import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/habits/providers/habits_provider.dart';
import 'package:focusly/features/home/widgets/continue_reading_widget.dart';
import 'package:focusly/features/home/widgets/groups_preview_widget.dart';
import 'package:focusly/features/home/widgets/home_life_score_widget.dart';
import 'package:focusly/features/home/widgets/home_weekly_review_due_banner.dart';
import 'package:focusly/features/home/widgets/level_xp_compact_widget.dart';
import 'package:focusly/features/home/widgets/quick_actions_row.dart';
import 'package:focusly/features/home/widgets/todays_focus_card.dart';
import 'package:focusly/features/home/widgets/todays_habits_row.dart';
import 'package:focusly/features/reading_tracker/models/book_model.dart';
import 'package:focusly/features/reading_tracker/providers/reading_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/features/weekly_review/providers/weekly_review_provider.dart';
import 'package:focusly/screens/home_screen.dart';

Widget _buildTestApp({
  required Widget home,
  List<dynamic> overrides = const [],
  Locale explicitLocale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides.isEmpty ? const [] : overrides.cast(),
    child: MaterialApp(
      locale: explicitLocale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
    await initializeDateFormatting('ar', null);
  });

  group('Flagship Home Feed UI & Widget Tests', () {
    testWidgets('Renders HomeScreen with Flagship Feed and core sections',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          home: const HomeScreen(),
        ),
      );
      await tester.pump();

      // Verify Greeting and Date
      expect(find.textContaining('Hello,'), findsOneWidget);
      expect(find.byType(LevelXpCompactWidget), findsOneWidget);
      expect(find.byType(QuickActionsRow), findsOneWidget);

      // Verify Quick Action Labels
      expect(find.text('Start Pomodoro'), findsOneWidget);
      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);

      // Verify Footer Card
      expect(find.text('Deep Focus & Workspace Ready'), findsOneWidget);
    });

    testWidgets('LevelXpCompactWidget renders rank title, emoji and responds to tap',
        (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          home: Scaffold(
            body: LevelXpCompactWidget(
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('🌱'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Lv. 1'), findsOneWidget);
      expect(find.text('0 / 100 XP'), findsOneWidget);

      await tester.tap(find.byType(LevelXpCompactWidget));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('TodaysFocusCard renders when tasks exist for today',
        (WidgetTester tester) async {
      final today = DateTime.now();

      final mockTasks = <TaskModel>[
        TaskModel(
          id: 'task_1',
          title: 'Submit Project Milestone',
          categoryId: 'work',
          priority: TaskPriority.high,
          date: today,
          done: false,
          time: const TimeOfDay(hour: 10, minute: 0),
          createdAt: DateTime.now(),
        ),
        TaskModel(
          id: 'task_2',
          title: 'Review PR feedback',
          categoryId: 'engineering',
          priority: TaskPriority.medium,
          date: today,
          done: false,
          time: const TimeOfDay(hour: 14, minute: 0),
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            tasksStreamProvider.overrideWith((ref) => Stream<List<TaskModel>>.value(mockTasks)),
          ],
          home: Scaffold(
            body: TodaysFocusCard(onViewAll: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Today's Focus"), findsOneWidget);
      expect(find.text('Submit Project Milestone'), findsOneWidget);
      expect(find.text('Review PR feedback'), findsOneWidget);
      expect(find.text('2 left today'), findsOneWidget);
    });

    testWidgets('TodaysFocusCard hides entirely when zero tasks for today',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            tasksStreamProvider.overrideWith((ref) => Stream<List<TaskModel>>.value([])),
          ],
          home: Scaffold(
            body: TodaysFocusCard(onViewAll: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Today's Focus"), findsNothing);
    });

    testWidgets('QuickActionsRow renders 3 starting actions',
        (WidgetTester tester) async {
      bool pomodoroStarted = false;

      await tester.pumpWidget(
        _buildTestApp(
          home: Scaffold(
            body: QuickActionsRow(
              onStartPomodoro: () => pomodoroStarted = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Start Pomodoro'), findsOneWidget);
      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);

      await tester.tap(find.text('Start Pomodoro'));
      await tester.pump();
      expect(pomodoroStarted, isTrue);
    });

    testWidgets('TodaysHabitsRow renders when habits exist',
        (WidgetTester tester) async {
      final mockHabits = <HabitModel>[
        HabitModel(
          id: 'habit_1',
          title: 'Morning Meditation',
          days: const [true, false, false, false, false, false, false],
          streak: 5,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            habitsStreamProvider.overrideWith((ref) => Stream<List<HabitModel>>.value(mockHabits)),
          ],
          home: const Scaffold(
            body: TodaysHabitsRow(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Today's Habits"), findsOneWidget);
      expect(find.text('Morning Meditation'), findsOneWidget);
      expect(find.text('🔥 5'), findsOneWidget);
    });

    testWidgets('TodaysHabitsRow hides entirely when zero habits exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            habitsStreamProvider.overrideWith((ref) => Stream<List<HabitModel>>.value([])),
          ],
          home: const Scaffold(
            body: TodaysHabitsRow(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text("Today's Habits"), findsNothing);
    });

    testWidgets('ContinueReadingWidget renders active reading book',
        (WidgetTester tester) async {
      final mockBooks = <BookModel>[
        BookModel(
          id: 'book_1',
          title: 'Deep Work',
          author: 'Cal Newport',
          totalPages: 300,
          currentPage: 150,
          status: 'reading',
          coverColor: 0xFF3B82F6,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            booksStreamProvider.overrideWith((ref) => Stream<List<BookModel>>.value(mockBooks)),
          ],
          home: const Scaffold(
            body: ContinueReadingWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Continue Reading'), findsOneWidget);
      expect(find.text('Deep Work'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('ContinueReadingWidget hides entirely when zero reading books exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            booksStreamProvider.overrideWith((ref) => Stream<List<BookModel>>.value([])),
          ],
          home: const Scaffold(
            body: ContinueReadingWidget(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Continue Reading'), findsNothing);
    });

    testWidgets('HomeWeeklyReviewDueBanner renders when review is due',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            isWeeklyReviewDueProvider.overrideWithValue(true),
          ],
          home: const Scaffold(
            body: HomeWeeklyReviewDueBanner(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Weekly Review Due'), findsOneWidget);
      expect(find.text('Start Review'), findsOneWidget);
    });

    testWidgets('HomeWeeklyReviewDueBanner hides entirely when review is not due',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          overrides: [
            isWeeklyReviewDueProvider.overrideWithValue(false),
          ],
          home: const Scaffold(
            body: HomeWeeklyReviewDueBanner(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Weekly Review Due'), findsNothing);
    });

    testWidgets('Arabic localization renders all Home feed strings',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestApp(
          explicitLocale: const Locale('ar'),
          home: const HomeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('إجراءات سريعة'), findsOneWidget);
      expect(find.text('بدء بومودورو'), findsOneWidget);
      expect(find.text('تدوين سريع'), findsOneWidget);
      expect(find.text('إضافة مهمة'), findsOneWidget);
    });
  });
}
