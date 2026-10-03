import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/annual_review/annual_review_page.dart';
import 'package:focusly/features/annual_review/models/annual_review_model.dart';
import 'package:focusly/features/annual_review/providers/annual_review_provider.dart';
import 'package:focusly/features/annual_review/services/year_stats_calculator.dart';
import 'package:focusly/features/annual_review/widgets/annual_review_form_modal.dart';
import 'package:focusly/features/energy_mood/models/checkin_model.dart';
import 'package:focusly/features/reading_tracker/models/book_model.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/workout_tracker/models/workout_model.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createAnnualReviewTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_annual_review'),
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
  final review2026 = AnnualReviewModel(
    id: 'rev2026',
    year: 2026,
    q1: 'Built and completed the Focusly platform with 35 rich features!',
    q2: 'Handled high complexity by enforcing modularity and automated testing.',
    q3: 'Consistent daily actions compound into exponential results.',
    q4: 'Expand into global reach and support multi-platform sync.',
    createdAt: DateTime(2026, 12, 31),
    updatedAt: DateTime(2026, 12, 31),
  );

  group('YearStatsCalculator Pure Logic Tests', () {
    test(
      'calculateYearStats computes counts and average energy accurately',
      () {
        final tasks = [
          TaskModel(
            id: 't1',
            title: 'Done 2026 Task',
            categoryId: 'cat1',
            date: DateTime(2026, 3, 10),
            done: true,
            createdAt: DateTime(2026, 3, 10),
          ),
          TaskModel(
            id: 't2',
            title: 'Pending 2026 Task',
            categoryId: 'cat1',
            date: DateTime(2026, 4, 15),
            done: false,
            createdAt: DateTime(2026, 4, 15),
          ),
          TaskModel(
            id: 't3',
            title: 'Done 2025 Task',
            categoryId: 'cat1',
            date: DateTime(2025, 11, 1),
            done: true,
            createdAt: DateTime(2025, 11, 1),
          ),
        ];

        final workouts = [
          WorkoutModel(
            id: 'w1',
            type: 'gym',
            durationMin: 45,
            date: DateTime(2026, 2, 14),
            createdAt: DateTime(2026, 2, 14),
            updatedAt: DateTime(2026, 2, 14),
          ),
          WorkoutModel(
            id: 'w2',
            type: 'running',
            durationMin: 30,
            date: DateTime(2026, 7, 20),
            createdAt: DateTime(2026, 7, 20),
            updatedAt: DateTime(2026, 7, 20),
          ),
          WorkoutModel(
            id: 'w3',
            type: 'swim',
            durationMin: 60,
            date: DateTime(2025, 8, 10),
            createdAt: DateTime(2025, 8, 10),
            updatedAt: DateTime(2025, 8, 10),
          ),
        ];

        final books = [
          BookModel(
            id: 'b1',
            title: 'Deep Work',
            author: 'Cal Newport',
            status: 'done',
            finishDate: DateTime(2026, 5, 20),
            createdAt: DateTime(2026, 5, 1),
            updatedAt: DateTime(2026, 5, 20),
          ),
          BookModel(
            id: 'b2',
            title: 'Atomic Habits',
            author: 'James Clear',
            status: 'reading',
            createdAt: DateTime(2026, 6, 1),
            updatedAt: DateTime(2026, 6, 1),
          ),
          BookModel(
            id: 'b3',
            title: 'Essentialism',
            author: 'Greg McKeown',
            status: 'done',
            finishDate: DateTime(2025, 12, 15),
            createdAt: DateTime(2025, 12, 1),
            updatedAt: DateTime(2025, 12, 15),
          ),
        ];

        final checkins = [
          CheckinModel(
            date: '2026-03-01',
            energy: 4,
            mood: '😊',
            createdAt: DateTime(2026, 3, 1),
            updatedAt: DateTime(2026, 3, 1),
          ),
          CheckinModel(
            date: '2026-03-02',
            energy: 5,
            mood: '🤩',
            createdAt: DateTime(2026, 3, 2),
            updatedAt: DateTime(2026, 3, 2),
          ),
          CheckinModel(
            date: '2025-05-01',
            energy: 2,
            mood: '😞',
            createdAt: DateTime(2025, 5, 1),
            updatedAt: DateTime(2025, 5, 1),
          ),
        ];

        final stats2026 = calculateYearStats(
          2026,
          tasks: tasks,
          workouts: workouts,
          books: books,
          checkins: checkins,
        );

        expect(stats2026.tasks, equals(1));
        expect(stats2026.workouts, equals(2));
        expect(stats2026.books, equals(1));
        expect(stats2026.avgEnergy, equals(4.5));
        expect(stats2026.formattedEnergy, equals('4.5'));

        // Test year with 0 checkins returns dash
        final statsEmpty = calculateYearStats(2024);
        expect(statsEmpty.formattedEnergy, equals('−'));
      },
    );
  });

  group('AnnualReviewModel Unit Tests', () {
    test('Model serialization and copyWith', () {
      final map = review2026.toMap();
      expect(map['year'], equals(2026));
      expect(map['q1'], contains('Focusly platform'));

      final fromMap = AnnualReviewModel.fromMap(map, 'rev2026');
      expect(fromMap.id, equals('rev2026'));
      expect(fromMap.year, equals(2026));
      expect(fromMap.q2, contains('modularity'));

      final copy = review2026.copyWith(year: 2027);
      expect(copy.year, equals(2027));
      expect(copy.q1, equals(review2026.q1));
    });
  });

  group('AnnualReviewPage UI & Widget Tests', () {
    testWidgets('Renders empty state when 0 reviews exist', (tester) async {
      await tester.pumpWidget(
        createAnnualReviewTestWidget(
          child: const AnnualReviewPage(),
          overrides: [
            annualReviewsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Annual Review'), findsOneWidget);
      expect(find.text('Perform your first annual review'), findsOneWidget);
      expect(find.text('Start Review'), findsWidgets);
    });

    testWidgets(
      'Renders review card with 4-cell stats strip and 4 reflection blocks',
      (tester) async {
        await tester.pumpWidget(
          createAnnualReviewTestWidget(
            child: const AnnualReviewPage(),
            overrides: [
              annualReviewsStreamProvider.overrideWith(
                (ref) => Stream.value([review2026]),
              ),
              yearStatsProvider.overrideWith(
                (ref, year) => const YearStatsData(
                  tasks: 124,
                  workouts: 88,
                  books: 12,
                  avgEnergy: 4.2,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('2026'), findsOneWidget);
        expect(find.text('Workouts'), findsOneWidget);
        expect(find.text('88'), findsOneWidget);
        expect(find.text('Tasks Done'), findsOneWidget);
        expect(find.text('124'), findsOneWidget);
        expect(find.text('Books Read'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('Avg Energy'), findsOneWidget);
        expect(find.text('4.2'), findsOneWidget);

        expect(find.text('Biggest Achievement:'), findsOneWidget);
        expect(
          find.text(
            'Built and completed the Focusly platform with 35 rich features!',
          ),
          findsOneWidget,
        );

        // Scroll to view subsequent reflection blocks
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();

        expect(find.text('Biggest Obstacle & How Handled:'), findsOneWidget);
        expect(find.text('Top Lessons Learned:'), findsOneWidget);
        expect(find.text('Plan & Vision for Next Year:'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer includes Annual Review in Analytics section',
      (tester) async {
        await tester.pumpWidget(
          createAnnualReviewTestWidget(
            child: const HomeScreen(),
            overrides: [
              annualReviewsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        expect(find.text('ANALYTICS'), findsOneWidget);
        expect(find.text('Annual Review'), findsOneWidget);
      },
    );

    testWidgets('Arabic localization renders all Annual Review texts', (
      tester,
    ) async {
      await tester.pumpWidget(
        createAnnualReviewTestWidget(
          locale: const Locale('ar'),
          child: const AnnualReviewPage(),
          overrides: [
            annualReviewsStreamProvider.overrideWith(
              (ref) => Stream.value([review2026]),
            ),
            yearStatsProvider.overrideWith(
              (ref, year) => const YearStatsData(
                tasks: 50,
                workouts: 30,
                books: 5,
                avgEnergy: 4.0,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المراجعة السنوية'), findsOneWidget);
      expect(find.text('التمارين'), findsOneWidget);
      expect(find.text('المهام المنجزة'), findsOneWidget);
      expect(find.text('الكتب المقروءة'), findsOneWidget);
      expect(find.text('معدل النشاط'), findsOneWidget);
      expect(find.text('أكبر إنجاز:'), findsOneWidget);
    });
  });

  group('AnnualReviewFormModal Tests', () {
    testWidgets('Validates required reflection fields', (tester) async {
      await tester.pumpWidget(
        createAnnualReviewTestWidget(
          child: const Scaffold(body: AnnualReviewFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Annual Review'), findsOneWidget);

      // Scroll to save button and tap
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Review'));
      await tester.pumpAndSettle();

      expect(find.text('All reflection fields are required'), findsWidgets);
    });

    testWidgets(
      'Renders pre-filled fields in edit mode and shows delete button',
      (tester) async {
        await tester.pumpWidget(
          createAnnualReviewTestWidget(
            child: Scaffold(
              body: AnnualReviewFormModal(reviewToEdit: review2026),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Annual Review'), findsOneWidget);
        expect(
          find.text(
            'Built and completed the Focusly platform with 35 rich features!',
          ),
          findsOneWidget,
        );

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save Review'), findsOneWidget);
        expect(find.text('Delete Review'), findsOneWidget);
      },
    );
  });
}
