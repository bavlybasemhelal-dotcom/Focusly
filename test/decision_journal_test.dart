import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/decision_journal/decision_journal_page.dart';
import 'package:focusly/features/decision_journal/models/decision_model.dart';
import 'package:focusly/features/decision_journal/providers/decision_journal_provider.dart';
import 'package:focusly/features/decision_journal/widgets/decision_card.dart';
import 'package:focusly/features/decision_journal/widgets/decision_form_modal.dart';
import 'package:focusly/features/decision_journal/widgets/decision_stats_header.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createDecisionJournalTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_decisions'),
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
  group('Decision Model & Serialization Tests', () {
    test(
      'DecisionModel serializes toMap and deserializes fromMap correctly',
      () {
        final now = DateTime(2026, 8, 24, 10, 30);
        final decision = DecisionModel(
          id: 'dec_123',
          title: 'Switch to Monorepo Architecture',
          date: now,
          rationale: 'Simplify cross-package dependencies and unified CI/CD.',
          expected: 'Reduce deployment friction by 50%.',
          outcome: 'CI build time was halved and repository sync was seamless.',
          reviewed: true,
          createdAt: now,
          updatedAt: now,
        );

        final map = decision.toMap();
        expect(map['id'], equals('dec_123'));
        expect(map['title'], equals('Switch to Monorepo Architecture'));
        expect(
          map['rationale'],
          equals('Simplify cross-package dependencies and unified CI/CD.'),
        );
        expect(map['expected'], equals('Reduce deployment friction by 50%.'));
        expect(
          map['outcome'],
          equals('CI build time was halved and repository sync was seamless.'),
        );
        expect(map['reviewed'], isTrue);

        final reconstructed = DecisionModel.fromMap(map, 'dec_123');
        expect(reconstructed.id, equals('dec_123'));
        expect(reconstructed.title, equals(decision.title));
        expect(reconstructed.rationale, equals(decision.rationale));
        expect(reconstructed.expected, equals(decision.expected));
        expect(reconstructed.outcome, equals(decision.outcome));
        expect(reconstructed.reviewed, isTrue);
      },
    );

    test('DecisionModel copyWith and equality work as expected', () {
      final now = DateTime(2026, 8, 24);
      final d1 = DecisionModel(
        id: '1',
        title: 'Test Decision',
        date: now,
        rationale: 'Rationale 1',
        expected: 'Expected 1',
        createdAt: now,
        updatedAt: now,
      );

      final d2 = d1.copyWith(outcome: 'Actual result observed', reviewed: true);

      expect(d2.outcome, equals('Actual result observed'));
      expect(d2.reviewed, isTrue);
      expect(d2.title, equals(d1.title));
      expect(d1 == d2, isFalse);

      final d3 = d1.copyWith();
      expect(d1 == d3, isTrue);
    });
  });

  group('Decision Journal Providers Tests', () {
    test(
      'decisionStatsProvider calculates pending and reviewed counts correctly',
      () {
        final now = DateTime.now();
        final decisions = [
          DecisionModel(
            id: '1',
            title: 'Pending Decision 1',
            date: now,
            rationale: 'Why 1',
            expected: 'Prediction 1',
            reviewed: false,
            createdAt: now,
            updatedAt: now,
          ),
          DecisionModel(
            id: '2',
            title: 'Pending Decision 2',
            date: now,
            rationale: 'Why 2',
            expected: 'Prediction 2',
            reviewed: false,
            createdAt: now,
            updatedAt: now,
          ),
          DecisionModel(
            id: '3',
            title: 'Reviewed Decision 3',
            date: now,
            rationale: 'Why 3',
            expected: 'Prediction 3',
            outcome: 'Actual result',
            reviewed: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            decisionsStreamProvider.overrideWithValue(AsyncData(decisions)),
          ],
        );
        addTearDown(container.dispose);

        final stats = container.read(decisionStatsProvider);
        expect(stats.totalCount, equals(3));
        expect(stats.pendingCount, equals(2));
        expect(stats.reviewedCount, equals(1));
      },
    );

    test(
      'filteredDecisionsProvider filters decisions by active DecisionFilter',
      () {
        final now = DateTime.now();
        final decisions = [
          DecisionModel(
            id: '1',
            title: 'Pending Item',
            date: now,
            rationale: 'R1',
            expected: 'E1',
            reviewed: false,
            createdAt: now,
            updatedAt: now,
          ),
          DecisionModel(
            id: '2',
            title: 'Reviewed Item',
            date: now,
            rationale: 'R2',
            expected: 'E2',
            outcome: 'Done',
            reviewed: true,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            decisionsStreamProvider.overrideWithValue(AsyncData(decisions)),
            decisionFilterProvider.overrideWith(DecisionFilterNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        // Default: All
        expect(container.read(filteredDecisionsProvider).length, equals(2));

        // Filter: Pending
        container
            .read(decisionFilterProvider.notifier)
            .setFilter(DecisionFilter.pending);
        final pendingList = container.read(filteredDecisionsProvider);
        expect(pendingList.length, equals(1));
        expect(pendingList.first.title, equals('Pending Item'));

        // Filter: Reviewed
        container
            .read(decisionFilterProvider.notifier)
            .setFilter(DecisionFilter.reviewed);
        final reviewedList = container.read(filteredDecisionsProvider);
        expect(reviewedList.length, equals(1));
        expect(reviewedList.first.title, equals('Reviewed Item'));
      },
    );
  });

  group('Decision Journal UI & Widget Tests', () {
    testWidgets('DecisionStatsHeader renders counts and labels', (
      tester,
    ) async {
      final now = DateTime.now();
      final decisions = [
        DecisionModel(
          id: '1',
          title: 'Pending 1',
          date: now,
          rationale: 'Why',
          expected: 'Expected',
          reviewed: false,
          createdAt: now,
          updatedAt: now,
        ),
        DecisionModel(
          id: '2',
          title: 'Reviewed 1',
          date: now,
          rationale: 'Why',
          expected: 'Expected',
          outcome: 'Observed',
          reviewed: true,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createDecisionJournalTestWidget(
          child: const Scaffold(body: DecisionStatsHeader()),
          overrides: [
            decisionsStreamProvider.overrideWithValue(AsyncData(decisions)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Review'), findsOneWidget);
      expect(find.text('Reviewed Decisions'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets(
      'DecisionCard renders unreviewed decision with evaluate button',
      (tester) async {
        final now = DateTime(2026, 8, 24);
        final decision = DecisionModel(
          id: '10',
          title: 'Adopt Flutter 3.29',
          date: now,
          rationale:
              'Get latest performance improvements and WebAssembly boost.',
          expected: 'Faster load time and smoother animations.',
          reviewed: false,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createDecisionJournalTestWidget(
            child: Scaffold(body: DecisionCard(decision: decision)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Adopt Flutter 3.29'), findsOneWidget);
        expect(find.text('⏳ Pending Review'), findsOneWidget);
        expect(find.text('Rationale'), findsOneWidget);
        expect(
          find.text(
            'Get latest performance improvements and WebAssembly boost.',
          ),
          findsOneWidget,
        );
        expect(find.text('Expected Outcome'), findsOneWidget);
        expect(
          find.text('Faster load time and smoother animations.'),
          findsOneWidget,
        );
        expect(find.text('Evaluate and Review Decision'), findsOneWidget);
      },
    );

    testWidgets(
      'DecisionCard renders reviewed decision with actual outcome inset',
      (tester) async {
        final now = DateTime(2026, 8, 24);
        final decision = DecisionModel(
          id: '20',
          title: 'Hire Senior Backend Engineer',
          date: now,
          rationale: 'Accelerate API scalability and reduce tech debt.',
          expected: 'Release new payment APIs 3 weeks faster.',
          outcome: 'Candidate joined and shipped payment microservice on time.',
          reviewed: true,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createDecisionJournalTestWidget(
            child: Scaffold(body: DecisionCard(decision: decision)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Hire Senior Backend Engineer'), findsOneWidget);
        expect(find.text('✅ Reviewed'), findsOneWidget);
        expect(find.text('Actual Outcome'), findsOneWidget);
        expect(
          find.text(
            'Candidate joined and shipped payment microservice on time.',
          ),
          findsOneWidget,
        );
        expect(find.text('Evaluate and Review Decision'), findsNothing);
      },
    );

    testWidgets('DecisionFormModal validates required fields on save attempt', (
      tester,
    ) async {
      await tester.pumpWidget(
        createDecisionJournalTestWidget(
          child: const Scaffold(body: DecisionFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log New Decision'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Ensure Save button is visible in scrollable modal before tapping
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();

      // Attempt to save without entering required fields
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Title, rationale, and expected outcome are required'),
        findsOneWidget,
      );
    });

    testWidgets(
      'DecisionJournalPage renders empty state when no decisions exist',
      (tester) async {
        await tester.pumpWidget(
          createDecisionJournalTestWidget(
            child: const DecisionJournalPage(),
            overrides: [
              decisionsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Decision Journal'), findsOneWidget);
        expect(find.text('🤔 Log your first key decision'), findsOneWidget);
        expect(find.text('Log Decision'), findsWidgets);
      },
    );

    testWidgets('Navigation Drawer includes Decision Journal item', (
      tester,
    ) async {
      await tester.pumpWidget(
        createDecisionJournalTestWidget(
          child: const HomeScreen(),
          overrides: [
            decisionsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open navigation drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside the drawer and verify "Decision Journal" is present
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Decision Journal'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Decision Journal'), findsOneWidget);
    });
  });
}
