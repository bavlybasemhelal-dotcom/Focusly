import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/gtd/models/inbox_item_model.dart';
import 'package:focusly/features/gtd/providers/gtd_provider.dart';
import 'package:focusly/features/para/models/para_project_model.dart';
import 'package:focusly/features/para/providers/para_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/features/weekly_review/models/weekly_review_model.dart';
import 'package:focusly/features/weekly_review/providers/weekly_review_provider.dart';
import 'package:focusly/features/weekly_review/widgets/weekly_review_wizard.dart';
import 'package:focusly/screens/home_screen.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';

Widget createWeeklyReviewTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_review'),
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

void main() {
  group('Weekly Review Model & Calculation Tests', () {
    test('isReviewDue returns true when no review has ever occurred', () {
      expect(isReviewDue(null), isTrue);
    });

    test('isReviewDue returns false when review was 3 days ago', () {
      final now = DateTime(2026, 8, 24);
      final lastReview = DateTime(2026, 8, 21);
      expect(isReviewDue(lastReview, now), isFalse);
    });

    test('isReviewDue returns true when review was 7 or more days ago', () {
      final now = DateTime(2026, 8, 24);
      final sevenDaysAgo = DateTime(2026, 8, 17);
      final tenDaysAgo = DateTime(2026, 8, 14);

      expect(isReviewDue(sevenDaysAgo, now), isTrue);
      expect(isReviewDue(tenDaysAgo, now), isTrue);
    });

    test('WeeklyReviewModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 24);
      final model = WeeklyReviewModel(
        id: 'rev_1',
        date: now,
        priorities: ['Ship v1.0', 'Write unit tests', 'Hire designer'],
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['id'], equals('rev_1'));
      expect(map['priorities'], equals(['Ship v1.0', 'Write unit tests', 'Hire designer']));

      final reconstructed = WeeklyReviewModel.fromMap(map, 'rev_1');
      expect(reconstructed.priorities.length, equals(3));
      expect(reconstructed.priorities.first, equals('Ship v1.0'));
    });
  });

  group('Weekly Review Wizard UI Tests', () {
    testWidgets('Step 1 Mind Sweep renders and moves to step 2', (tester) async {
      await tester.pumpWidget(
        createWeeklyReviewTestWidget(
          child: const WeeklyReviewWizard(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mind Sweep'), findsOneWidget);
      expect(find.text('1 / 6'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Enter thoughts
      await tester.enterText(
        find.byType(TextFormField),
        'Buy groceries\nSchedule dentist\n',
      );
      await tester.pump();

      // Click Continue
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Should advance to Step 2: Get Clear
      expect(find.text('Get Clear'), findsOneWidget);
      expect(find.text('2 / 6'), findsOneWidget);
    });

    testWidgets('Step 2 to 4 render counts for Inbox, Projects, and Tasks', (tester) async {
      final now = DateTime.now();
      final inboxItems = [
        InboxItemModel(id: 'i1', text: 'Clean desk', processed: false, createdAt: now),
        InboxItemModel(id: 'i2', text: 'Read book', processed: false, createdAt: now),
      ];

      final projects = [
        ParaProjectModel(id: 'p1', title: 'Mobile App', areaId: 'a1', createdAt: now),
      ];

      final tasks = [
        TaskModel(id: 't1', title: 'Task 1', categoryId: 'work', done: false, date: now, createdAt: now),
        TaskModel(id: 't2', title: 'Task 2', categoryId: 'work', done: false, date: now, createdAt: now),
        TaskModel(id: 't3', title: 'Task 3', categoryId: 'work', done: true, date: now, createdAt: now),
      ];

      await tester.pumpWidget(
        createWeeklyReviewTestWidget(
          child: const WeeklyReviewWizard(),
          overrides: [
            inboxStreamProvider.overrideWith((ref) => Stream.value(inboxItems)),
            paraProjectsStreamProvider.overrideWithValue(AsyncData(projects)),
            tasksStreamProvider.overrideWithValue(AsyncData(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Advance to Step 2: Get Clear Inbox
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Get Clear'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 unprocessed items
      expect(find.text('Go to Inbox'), findsOneWidget);

      // Advance to Step 3: Get Current Projects
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Get Current'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // 1 active project
      expect(find.text('View Projects'), findsOneWidget);

      // Advance to Step 4: Get Current Tasks
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Get Current'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 active uncompleted tasks
    });

    testWidgets('Step 5 Someday/Maybe displays items and allows step advance to Step 6', (tester) async {
      final now = DateTime.now();
      final somedayTask = TaskModel(
        id: 's1',
        title: 'Learn Rust Language',
        categoryId: 'work',
        listType: 'someday',
        done: false,
        date: now,
        createdAt: now,
      );

      final tasks = [somedayTask];

      await tester.pumpWidget(
        createWeeklyReviewTestWidget(
          child: const WeeklyReviewWizard(),
          overrides: [
            tasksStreamProvider.overrideWithValue(AsyncData(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Advance through Steps 1 -> 2 -> 3 -> 4 -> 5
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
      }

      // Step 5: Someday / Maybe
      expect(find.text('Someday / Maybe'), findsOneWidget);
      expect(find.text('Learn Rust Language'), findsOneWidget);
      expect(find.text('Activate'), findsOneWidget);

      // Advance to Step 6: Get Creative
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Get Creative'), findsOneWidget);
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.text('Finish Review (+40 XP)'), findsOneWidget);
    });
  });

  group('Navigation Drawer Weekly Review Due Badge Tests', () {
    testWidgets('Drawer displays Review due badge when isWeeklyReviewDueProvider is true', (tester) async {
      await tester.pumpWidget(
        createWeeklyReviewTestWidget(
          child: const HomeScreen(),
          overrides: [
            isWeeklyReviewDueProvider.overrideWithValue(true),
            morningIntentionDismissedProvider.overrideWith(MockDismissedNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Review'), findsOneWidget);
      expect(find.text('Review due'), findsOneWidget);
    });
  });
}
