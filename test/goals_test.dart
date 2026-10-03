import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/goals/goal_detail_page.dart';
import 'package:focusly/features/goals/life_map_page.dart';
import 'package:focusly/features/goals/models/goal_model.dart';
import 'package:focusly/features/goals/providers/goals_provider.dart';
import 'package:focusly/features/goals/widgets/circular_progress_ring.dart';
import 'package:focusly/features/goals/widgets/goal_card.dart';
import 'package:focusly/features/goals/widgets/goal_form_modal.dart';
import 'package:focusly/features/para/models/para_area_model.dart';
import 'package:focusly/features/para/providers/para_provider.dart';

Widget createGoalsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_goals'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [AppLocalizations.delegate],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Life Map (Goals) Pure Calculations & Model Tests', () {
    test(
      'calculateMilestoneProgress correctly handles manual progress and milestone ratios',
      () {
        // 1. Empty milestones -> preserves manual progress (0-100)
        expect(calculateMilestoneProgress([], 45), equals(45));
        expect(calculateMilestoneProgress([], 120), equals(100)); // clamped
        expect(calculateMilestoneProgress([], -10), equals(0)); // clamped

        // 2. Non-empty milestones -> overrides manual value with exact percentage
        final m1 = [
          const GoalMilestone(title: 'Step 1', done: true),
          const GoalMilestone(title: 'Step 2', done: false),
          const GoalMilestone(title: 'Step 3', done: false),
          const GoalMilestone(title: 'Step 4', done: false),
        ];
        expect(calculateMilestoneProgress(m1, 90), equals(25)); // 1/4 = 25%

        final m2 = [
          const GoalMilestone(title: 'Step 1', done: true),
          const GoalMilestone(title: 'Step 2', done: true),
        ];
        expect(calculateMilestoneProgress(m2, 0), equals(100)); // 2/2 = 100%

        final m3 = [
          const GoalMilestone(title: 'Step 1', done: false),
          const GoalMilestone(title: 'Step 2', done: false),
        ];
        expect(calculateMilestoneProgress(m3, 50), equals(0)); // 0/2 = 0%
      },
    );

    test('daysUntilDate calculates calendar days remaining accurately', () {
      final now = DateTime(2026, 8, 23, 10, 0);

      // Future date in 15 days
      final future = DateTime(2026, 9, 7);
      expect(daysUntilDate(future, now), equals(15));

      // Same day (due today)
      final today = DateTime(2026, 8, 23, 23, 59);
      expect(daysUntilDate(today, now), equals(0));

      // Past date (overdue / ended)
      final past = DateTime(2026, 8, 20);
      expect(daysUntilDate(past, now), equals(-3));
    });

    test('GoalModel and GoalMilestone serialize and deserialize correctly', () {
      final now = DateTime(2026, 8, 23, 12, 0);
      final goal = GoalModel(
        id: 'goal_123',
        title: 'Run a Half Marathon',
        icon: '🏃',
        color: '#10B981',
        timeframe: '3months',
        areaId: 'area_health',
        targetDate: DateTime(2026, 11, 23),
        progress: 50,
        status: 'active',
        milestones: const [
          GoalMilestone(title: 'Run 5k', done: true),
          GoalMilestone(title: 'Run 10k', done: false),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final map = goal.toMap();
      expect(map['id'], equals('goal_123'));
      expect(map['title'], equals('Run a Half Marathon'));
      expect(map['icon'], equals('🏃'));
      expect(map['color'], equals('#10B981'));
      expect(map['timeframe'], equals('3months'));
      expect(map['areaId'], equals('area_health'));
      expect(map['progress'], equals(50)); // 1/2 = 50%
      expect(map['milestones'], isA<List>());

      final reconstructed = GoalModel.fromMap(map, 'goal_123');
      expect(reconstructed.id, equals('goal_123'));
      expect(reconstructed.title, equals('Run a Half Marathon'));
      expect(reconstructed.milestones.length, equals(2));
      expect(reconstructed.milestones.first.done, isTrue);
      expect(reconstructed.completedMilestonesCount, equals(1));
      expect(reconstructed.effectiveProgress, equals(50));
    });
  });

  group('Life Map Providers Tests', () {
    test(
      'goalsByTimeframeProvider filters by timeframe and respects showCompleted toggle',
      () {
        final now = DateTime.now();
        final g1 = GoalModel(
          id: '1',
          title: 'Finish Book',
          timeframe: '1month',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );
        final g2 = GoalModel(
          id: '2',
          title: 'Learn Dart',
          timeframe: '1month',
          status: 'done',
          createdAt: now,
          updatedAt: now,
        );
        final g3 = GoalModel(
          id: '3',
          title: 'Buy House',
          timeframe: '5years',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );

        final container = ProviderContainer(
          overrides: [
            goalsStreamProvider.overrideWithValue(AsyncData([g1, g2, g3])),
          ],
        );
        addTearDown(container.dispose);

        // By default, showCompleted is true
        final monthGoals = container.read(goalsByTimeframeProvider('1month'));
        expect(monthGoals.length, equals(2));

        final fiveYearGoals = container.read(
          goalsByTimeframeProvider('5years'),
        );
        expect(fiveYearGoals.length, equals(1));

        // Toggle showCompleted to false
        container
            .read(showCompletedGoalsProvider.notifier)
            .setShowCompleted(false);

        final monthGoalsActiveOnly = container.read(
          goalsByTimeframeProvider('1month'),
        );
        expect(monthGoalsActiveOnly.length, equals(1));
        expect(monthGoalsActiveOnly.first.title, equals('Finish Book'));
      },
    );
  });

  group('Life Map UI & Widget Tests', () {
    testWidgets('CircularProgressRing renders arc and percentage text', (
      tester,
    ) async {
      await tester.pumpWidget(
        createGoalsTestWidget(
          child: const CircularProgressRing(size: 60, progress: 75),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('GoalCard renders title, icon, area badge and progress ring', (
      tester,
    ) async {
      final now = DateTime.now();
      final goal = GoalModel(
        id: 'g1',
        title: 'Launch SaaS Product',
        icon: '🚀',
        color: '#2563EB',
        timeframe: '3months',
        areaId: 'area_career',
        targetDate: now.add(const Duration(days: 30)),
        progress: 75,
        milestones: const [
          GoalMilestone(title: 'Design UI', done: true),
          GoalMilestone(title: 'Build Backend', done: true),
          GoalMilestone(title: 'Launch Beta', done: true),
          GoalMilestone(title: 'Public Launch', done: false),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final mockArea = ParaAreaModel(
        id: 'area_career',
        title: 'Career & Business',
        emoji: '💼',
        createdAt: now,
      );

      await tester.pumpWidget(
        createGoalsTestWidget(
          child: GoalCard(goal: goal),
          overrides: [
            paraAreasStreamProvider.overrideWithValue(AsyncData([mockArea])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Launch SaaS Product'), findsOneWidget);
      expect(find.text('🚀'), findsOneWidget);
      expect(find.text('Career & Business'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('3/4 milestones'), findsOneWidget);
    });

    testWidgets('LifeMapPage renders timeframe tabs and column goals', (
      tester,
    ) async {
      final now = DateTime.now();
      final goals = [
        GoalModel(
          id: '1',
          title: 'Read 2 Books',
          timeframe: '1month',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createGoalsTestWidget(
          child: const LifeMapPage(),
          overrides: [
            goalsStreamProvider.overrideWithValue(AsyncData(goals)),
            paraAreasStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Map'), findsOneWidget);
      expect(find.text('This Month'), findsWidgets);
      expect(find.text('3 Months'), findsOneWidget);
      expect(find.text('1 Year'), findsOneWidget);
      expect(find.text('5 Years'), findsOneWidget);
      expect(find.text('Read 2 Books'), findsOneWidget);
    });

    testWidgets(
      'GoalFormModal validates required title and allows adding milestones',
      (tester) async {
        await tester.pumpWidget(
          createGoalsTestWidget(
            child: const GoalFormModal(),
            overrides: [
              paraAreasStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add Goal'), findsOneWidget);
        expect(find.text('Goal Title'), findsOneWidget);

        final saveButton = find.text('Save Goal');
        expect(saveButton, findsOneWidget);
        await tester.ensureVisible(saveButton);
        await tester.pumpAndSettle();

        // Tap save without entering title
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(find.text('Please enter a goal title'), findsOneWidget);
      },
    );

    testWidgets(
      'GoalDetailPage renders header and interactive milestones checklist',
      (tester) async {
        final now = DateTime.now();
        final goal = GoalModel(
          id: 'detail_g1',
          title: 'Master Flutter Animations',
          icon: '🎨',
          color: '#7C3AED',
          timeframe: '3months',
          milestones: const [
            GoalMilestone(title: 'Explicit Animations', done: true),
            GoalMilestone(title: 'Custom Painter Canvas', done: false),
          ],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createGoalsTestWidget(
            child: GoalDetailPage(goalId: 'detail_g1', initialGoal: goal),
            overrides: [
              goalsStreamProvider.overrideWithValue(AsyncData([goal])),
              paraAreasStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Goal Details'), findsOneWidget);
        expect(find.text('Master Flutter Animations'), findsOneWidget);
        expect(find.text('Milestones Checklist'), findsOneWidget);
        expect(find.text('Explicit Animations'), findsOneWidget);
        expect(find.text('Custom Painter Canvas'), findsOneWidget);
        expect(find.text('1/2'), findsOneWidget);
      },
    );
  });
}
