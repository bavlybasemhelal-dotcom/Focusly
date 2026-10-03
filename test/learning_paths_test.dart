import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/learning_paths/helpers/learning_path_helpers.dart';
import 'package:focusly/features/learning_paths/learning_paths_page.dart';
import 'package:focusly/features/learning_paths/models/learning_path_model.dart';
import 'package:focusly/features/learning_paths/providers/learning_paths_provider.dart';
import 'package:focusly/features/learning_paths/widgets/path_card.dart';
import 'package:focusly/features/learning_paths/widgets/path_form_modal.dart';
import 'package:focusly/features/learning_paths/widgets/path_step_row.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createLearningPathsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_learning_paths'),
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
  group('Learning Path Helpers Pure Function Tests', () {
    test(
      'resizeSteps expands steps and preserves existing day data by day number',
      () {
        final initialSteps = [
          const PathStepModel(
            day: 1,
            title: 'Introduction to Flutter',
            completed: true,
            subSteps: [
              PathSubStepModel(id: 's1', title: 'Install SDK', completed: true),
            ],
          ),
          const PathStepModel(
            day: 2,
            title: 'Widgets Deep Dive',
            completed: false,
          ),
        ];

        final resized = LearningPathHelpers.resizeSteps(initialSteps, 4);

        expect(resized.length, equals(4));
        expect(resized[0].day, equals(1));
        expect(resized[0].title, equals('Introduction to Flutter'));
        expect(resized[0].completed, isTrue);
        expect(resized[0].subSteps.length, equals(1));

        expect(resized[1].day, equals(2));
        expect(resized[1].title, equals('Widgets Deep Dive'));

        expect(resized[2].day, equals(3));
        expect(resized[2].title, equals(''));
        expect(resized[2].completed, isFalse);

        expect(resized[3].day, equals(4));
        expect(resized[3].title, equals(''));
      },
    );

    test(
      'resizeSteps shrinks steps and truncates days exceeding new total',
      () {
        final initialSteps = [
          const PathStepModel(day: 1, title: 'Day 1'),
          const PathStepModel(day: 2, title: 'Day 2'),
          const PathStepModel(day: 3, title: 'Day 3'),
        ];

        final resized = LearningPathHelpers.resizeSteps(initialSteps, 2);

        expect(resized.length, equals(2));
        expect(resized[0].title, equals('Day 1'));
        expect(resized[1].title, equals('Day 2'));
      },
    );

    test('evaluateDayCompletion evaluates sub-step checklists accurately', () {
      const stepWithIncompleteSubs = PathStepModel(
        day: 1,
        title: 'Topic',
        completed: false,
        subSteps: [
          PathSubStepModel(id: '1', title: 'Sub 1', completed: true),
          PathSubStepModel(id: '2', title: 'Sub 2', completed: false),
        ],
      );
      expect(
        LearningPathHelpers.evaluateDayCompletion(stepWithIncompleteSubs),
        isFalse,
      );

      const stepWithAllCompletedSubs = PathStepModel(
        day: 1,
        title: 'Topic',
        completed: false,
        subSteps: [
          PathSubStepModel(id: '1', title: 'Sub 1', completed: true),
          PathSubStepModel(id: '2', title: 'Sub 2', completed: true),
        ],
      );
      expect(
        LearningPathHelpers.evaluateDayCompletion(stepWithAllCompletedSubs),
        isTrue,
      );

      const stepWithNoSubs = PathStepModel(
        day: 1,
        title: 'Topic',
        completed: true,
        subSteps: [],
      );
      expect(LearningPathHelpers.evaluateDayCompletion(stepWithNoSubs), isTrue);
    });

    test('syncPathProgress recalculates progressDay across all steps', () {
      final now = DateTime.now();
      final path = LearningPathModel(
        id: 'p1',
        title: 'Mobile Architecture',
        totalDays: 3,
        steps: const [
          PathStepModel(day: 1, title: 'Day 1', completed: true),
          PathStepModel(
            day: 2,
            title: 'Day 2',
            completed: false,
            subSteps: [
              PathSubStepModel(id: '1', title: 'Task', completed: true),
            ],
          ),
          PathStepModel(day: 3, title: 'Day 3', completed: false),
        ],
        progressDay: 1,
        createdAt: now,
        updatedAt: now,
      );

      final synced = LearningPathHelpers.syncPathProgress(path);
      expect(
        synced.steps[1].completed,
        isTrue,
      ); // Auto-completed because all sub-steps are done
      expect(synced.progressDay, equals(2)); // Days 1 and 2 completed
      expect(synced.progressPercent, equals(67)); // 2 / 3 = 67%
    });
  });

  group('Learning Path Models Serialization Tests', () {
    test(
      'LearningPathModel serializes toMap and deserializes fromMap correctly',
      () {
        final now = DateTime(2026, 8, 24, 10, 0);
        final path = LearningPathModel(
          id: 'path_100',
          title: 'Rust Programming',
          totalDays: 14,
          steps: const [
            PathStepModel(
              day: 1,
              title: 'Ownership & Borrowing',
              completed: true,
              subSteps: [
                PathSubStepModel(
                  id: 'sub_1',
                  title: 'Read Chapter 4',
                  completed: true,
                ),
              ],
            ),
          ],
          progressDay: 1,
          createdAt: now,
          updatedAt: now,
        );

        final map = path.toMap();
        expect(map['title'], equals('Rust Programming'));
        expect(map['totalDays'], equals(14));
        expect(map['progressDay'], equals(1));

        final reconstructed = LearningPathModel.fromMap(map, 'path_100');
        expect(reconstructed.id, equals('path_100'));
        expect(reconstructed.title, equals('Rust Programming'));
        expect(reconstructed.totalDays, equals(14));
        expect(reconstructed.steps.length, equals(1));
        expect(reconstructed.steps[0].title, equals('Ownership & Borrowing'));
        expect(
          reconstructed.steps[0].subSteps[0].title,
          equals('Read Chapter 4'),
        );
      },
    );
  });

  group('Learning Paths UI & Widget Tests', () {
    testWidgets(
      'PathStepRow renders day pill, title, and completion controls',
      (tester) async {
        final now = DateTime.now();
        const step = PathStepModel(
          day: 1,
          title: 'Async/Await in Dart',
          completed: false,
          subSteps: [
            PathSubStepModel(
              id: '1',
              title: 'Futures vs Streams',
              completed: false,
            ),
          ],
        );

        final path = LearningPathModel(
          id: 'p1',
          title: 'Dart Masterclass',
          totalDays: 10,
          steps: const [step],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: Scaffold(
              body: PathStepRow(path: path, step: step),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Day 1'), findsOneWidget);
        expect(find.text('Async/Await in Dart'), findsOneWidget);
        expect(find.text('0/1'), findsOneWidget);
      },
    );

    testWidgets(
      'PathCard renders title, progress bar, and expands day breakdown',
      (tester) async {
        final now = DateTime.now();
        final path = LearningPathModel(
          id: 'p1',
          title: '30 Days of Design Systems',
          totalDays: 30,
          steps: const [
            PathStepModel(
              day: 1,
              title: 'Color Tokens & Grids',
              completed: true,
            ),
            PathStepModel(
              day: 2,
              title: 'Typography Hierarchy',
              completed: false,
            ),
          ],
          progressDay: 1,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: Scaffold(body: PathCard(path: path)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('30 Days of Design Systems'), findsOneWidget);
        expect(find.text('1 / 30 days completed (3%)'), findsOneWidget);
        expect(find.text('Expand Curriculum'), findsOneWidget);

        // Tap expand
        await tester.tap(find.text('Expand Curriculum'));
        await tester.pumpAndSettle();

        expect(find.text('Collapse Curriculum'), findsOneWidget);
        expect(find.text('Color Tokens & Grids'), findsOneWidget);
        expect(find.text('Typography Hierarchy'), findsOneWidget);
      },
    );

    testWidgets(
      'PathFormModal validates required title field and dynamic day list',
      (tester) async {
        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: const Scaffold(body: PathFormModal()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Learning Path'), findsOneWidget);
        expect(find.text('Curriculum Duration (Days)'), findsOneWidget);

        // Attempt save without title
        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Path title is required'), findsOneWidget);
      },
    );

    testWidgets(
      'LearningPathsPage renders empty state and switches to populated paths list',
      (tester) async {
        // 1. Empty state
        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: const LearningPathsPage(),
            overrides: [
              learningPathsStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Learning Paths'), findsOneWidget);
        expect(find.text('🛤️ Start your first learning path'), findsOneWidget);

        // 2. Populated list
        final now = DateTime.now();
        final paths = [
          LearningPathModel(
            id: 'p1',
            title: 'Algorithms & Data Structures',
            totalDays: 20,
            steps: const [
              PathStepModel(day: 1, title: 'Binary Search', completed: true),
            ],
            progressDay: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: const LearningPathsPage(),
            overrides: [
              learningPathsStreamProvider.overrideWithValue(AsyncData(paths)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Algorithms & Data Structures'), findsOneWidget);
        expect(find.text('1 / 20 days completed (5%)'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer contains Learning Paths item in Learning section',
      (tester) async {
        await tester.pumpWidget(
          createLearningPathsTestWidget(
            child: const HomeScreen(),
            overrides: [
              learningPathsStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open Navigation Drawer
        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Scroll inside drawer to find "Learning Paths"
        final drawerScrollable = find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Learning Paths'),
          50,
          scrollable: drawerScrollable,
        );
        expect(find.text('Learning Paths'), findsOneWidget);
      },
    );
  });
}
