import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/tasks/models/category_model.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/features/time_audit/models/time_audit_model.dart';
import 'package:focusly/features/time_audit/providers/time_audit_provider.dart';
import 'package:focusly/features/time_audit/time_audit_page.dart';
import 'package:focusly/features/time_audit/widgets/quick_log_bar.dart';
import 'package:focusly/features/time_audit/widgets/time_distribution_chart.dart';

Widget createTimeAuditTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_time_audit'),
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
  group('Time Audit Pure Functions & Model Tests', () {
    test(
      'estimateTaskHours returns correct heuristic hours based on priority',
      () {
        expect(estimateTaskHours(TaskPriority.high), equals(2.0));
        expect(estimateTaskHours(TaskPriority.medium), equals(1.0));
        expect(estimateTaskHours(TaskPriority.low), equals(0.5));
      },
    );

    test('isDateInPeriod filters week, month, and all time correctly', () {
      final now = DateTime(2026, 8, 24, 12, 0); // Monday

      // Same day
      expect(isDateInPeriod(DateTime(2026, 8, 24), 'week', now), isTrue);
      expect(isDateInPeriod(DateTime(2026, 8, 24), 'month', now), isTrue);
      expect(isDateInPeriod(DateTime(2026, 8, 24), 'all', now), isTrue);

      // Previous month
      expect(isDateInPeriod(DateTime(2026, 7, 24), 'month', now), isFalse);
      expect(isDateInPeriod(DateTime(2026, 7, 24), 'all', now), isTrue);
    });

    test(
      'computeCombinedCategoryHours aggregates manual logs and completed tasks estimates',
      () {
        final now = DateTime(2026, 8, 24, 12, 0);

        final logs = [
          TimeAuditLogModel(
            id: 'log1',
            category: 'work',
            hours: 2.5,
            date: now,
            createdAt: now,
          ),
          TimeAuditLogModel(
            id: 'log2',
            category: 'study',
            hours: 1.5,
            date: now,
            createdAt: now,
          ),
        ];

        final tasks = [
          TaskModel(
            id: 't1',
            title: 'High priority bug fix',
            categoryId: 'work',
            priority: TaskPriority.high, // +2.0 hrs
            done: true,
            date: now,
            createdAt: now,
          ),
          TaskModel(
            id: 't2',
            title: 'Low priority reading',
            categoryId: 'study',
            priority: TaskPriority.low, // +0.5 hrs
            done: true,
            date: now,
            createdAt: now,
          ),
          TaskModel(
            id: 't3',
            title: 'Incomplete task',
            categoryId: 'work',
            priority: TaskPriority.high,
            done: false, // ignored
            date: now,
            createdAt: now,
          ),
        ];

        final combined = computeCombinedCategoryHours(
          logs: logs,
          completedTasks: tasks,
          period: 'all',
          now: now,
        );

        // Only measured hours; priority is not a duration.
        expect(combined['work'], equals(2.5));
        // Task estimates are reported separately.
        expect(combined['study'], equals(1.5));
      },
    );

    test(
      'TimeAuditLogModel serialization and deserialization works correctly',
      () {
        final now = DateTime(2026, 8, 24, 12, 0);
        final log = TimeAuditLogModel(
          id: 'log_99',
          category: 'health',
          hours: 1.5,
          description: 'Gym Workout',
          date: now,
          createdAt: now,
        );

        final map = log.toMap();
        expect(map['id'], equals('log_99'));
        expect(map['category'], equals('health'));
        expect(map['hours'], equals(1.5));
        expect(map['description'], equals('Gym Workout'));

        final reconstructed = TimeAuditLogModel.fromMap(map, 'log_99');
        expect(reconstructed.id, equals('log_99'));
        expect(reconstructed.category, equals('health'));
        expect(reconstructed.hours, equals(1.5));
        expect(reconstructed.description, equals('Gym Workout'));
      },
    );
  });

  group('Time Audit Providers Tests', () {
    test('TimeAuditPeriodFilterNotifier changes period correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(timeAuditPeriodFilterProvider), equals('week'));
      container.read(timeAuditPeriodFilterProvider.notifier).setPeriod('month');
      expect(container.read(timeAuditPeriodFilterProvider), equals('month'));
    });

    test(
      'combinedTimeAuditStatsProvider computes percentages and totals correctly',
      () {
        final now = DateTime.now();
        final logs = [
          TimeAuditLogModel(
            id: '1',
            category: 'work',
            hours: 3.0,
            date: now,
            createdAt: now,
          ),
          TimeAuditLogModel(
            id: '2',
            category: 'study',
            hours: 1.0,
            date: now,
            createdAt: now,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            timeAuditLogsStreamProvider.overrideWithValue(AsyncData(logs)),
            tasksStreamProvider.overrideWithValue(const AsyncData([])),
            timeAuditPeriodFilterProvider.overrideWith(
              TimeAuditPeriodFilterNotifier.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        final stats = container.read(combinedTimeAuditStatsProvider);
        expect(stats.totalHours, equals(4.0));
        expect(stats.getPercentage('work'), equals(75.0)); // 3/4 = 75%
        expect(stats.getPercentage('study'), equals(25.0)); // 1/4 = 25%
        expect(stats.sortedCategories.first, equals('work'));
      },
    );
  });

  group('Time Audit UI & Widget Tests', () {
    testWidgets('QuickLogBar renders fields and validates hours input', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTimeAuditTestWidget(
          child: const QuickLogBar(),
          overrides: [
            categoriesProvider.overrideWithValue(
              const AsyncData(TaskCategory.defaultCategories),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Log'), findsOneWidget);
      expect(find.text('Log Time'), findsOneWidget);

      // Clear hours input
      final hoursField = find.widgetWithText(TextFormField, '1');
      await tester.enterText(hoursField, '');
      await tester.tap(find.text('Log Time'));
      await tester.pumpAndSettle();

      expect(find.text('Enter > 0'), findsOneWidget);
    });

    testWidgets(
      'TimeDistributionChart renders category progress and empty state',
      (tester) async {
        final now = DateTime.now();
        final logs = [
          TimeAuditLogModel(
            id: '1',
            category: 'work',
            hours: 4.0,
            date: now,
            createdAt: now,
          ),
        ];

        await tester.pumpWidget(
          createTimeAuditTestWidget(
            child: const TimeDistributionChart(),
            overrides: [
              timeAuditLogsStreamProvider.overrideWithValue(AsyncData(logs)),
              tasksStreamProvider.overrideWithValue(const AsyncData([])),
              categoriesProvider.overrideWithValue(
                const AsyncData(TaskCategory.defaultCategories),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Time Distribution'), findsOneWidget);
        expect(find.text('4.0 hrs'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
      },
    );

    testWidgets(
      'TimeAuditPage renders full page with period selectors and manual entries',
      (tester) async {
        final now = DateTime.now();
        final logs = [
          TimeAuditLogModel(
            id: 'l1',
            category: 'study',
            hours: 2.0,
            description: 'Math Practice',
            date: now,
            createdAt: now,
          ),
        ];

        await tester.pumpWidget(
          createTimeAuditTestWidget(
            child: const TimeAuditPage(),
            overrides: [
              timeAuditLogsStreamProvider.overrideWithValue(AsyncData(logs)),
              tasksStreamProvider.overrideWithValue(const AsyncData([])),
              categoriesProvider.overrideWithValue(
                const AsyncData(TaskCategory.defaultCategories),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Time Audit'), findsOneWidget);
        expect(find.text('This Week'), findsOneWidget);
        expect(find.text('This Month'), findsOneWidget);
        expect(find.text('All Time'), findsOneWidget);
        expect(find.text('Math Practice'), findsOneWidget);
        expect(find.text('2.0 hrs'), findsWidgets);
      },
    );
  });
}
