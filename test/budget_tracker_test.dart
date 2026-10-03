import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/budget_tracker/budget_tracker_page.dart';
import 'package:focusly/features/budget_tracker/helpers/budget_helpers.dart';
import 'package:focusly/features/budget_tracker/models/budget_models.dart';
import 'package:focusly/features/budget_tracker/providers/budget_provider.dart';
import 'package:focusly/features/budget_tracker/widgets/budget_config_modal.dart';
import 'package:focusly/features/budget_tracker/widgets/transaction_form_modal.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createBudgetTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_budget'),
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
  group('BudgetHelpers Unit Tests', () {
    final now = DateTime.now();
    final thisMonthTx = [
      BudgetTransactionModel(
        id: '1',
        amount: 3000.0,
        type: TransactionType.income,
        category: 'salary',
        date: now,
        note: 'Monthly salary',
        createdAt: now,
        updatedAt: now,
      ),
      BudgetTransactionModel(
        id: '2',
        amount: 500.0,
        type: TransactionType.income,
        category: 'freelance',
        date: now,
        note: 'Side project',
        createdAt: now,
        updatedAt: now,
      ),
      BudgetTransactionModel(
        id: '3',
        amount: 400.0,
        type: TransactionType.expense,
        category: 'food',
        date: now,
        note: 'Groceries',
        createdAt: now,
        updatedAt: now,
      ),
      BudgetTransactionModel(
        id: '4',
        amount: 150.0,
        type: TransactionType.expense,
        category: 'transport',
        date: now,
        note: null,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test(
      'computeMonthSummary aggregates totalIncome, totalExpenses and balance',
      () {
        final summary = BudgetHelpers.computeMonthSummary(thisMonthTx);

        expect(summary.totalIncome, equals(3500.0));
        expect(summary.totalExpenses, equals(550.0));
        expect(summary.balance, equals(2950.0));
        expect(
          summary.formatCurrency(summary.totalIncome),
          equals('\$3500.00'),
        );
        expect(summary.formatCurrency(summary.balance), equals('\$2950.00'));
      },
    );

    test('computeCategorySpending aggregates expense amounts per category', () {
      final spending = BudgetHelpers.computeCategorySpending(thisMonthTx);

      expect(spending['food'], equals(400.0));
      expect(spending['transport'], equals(150.0));
      expect(
        spending['salary'],
        isNull,
      ); // Income is not in expense spending map
    });

    test(
      'getRelevantExpenseCategories filters categories with spending or limits',
      () {
        final spending = {'food': 200.0, 'bills': 100.0};
        final limits = {'food': 500.0, 'entertainment': 150.0};

        final relevant = BudgetHelpers.getRelevantExpenseCategories(
          spending: spending,
          limits: limits,
        );

        // food (has spending & limit), bills (has spending only), entertainment (has limit only)
        final ids = relevant.map((r) => r.category.id).toList();
        expect(ids, contains('food'));
        expect(ids, contains('bills'));
        expect(ids, contains('entertainment'));
        expect(ids, isNot(contains('education'))); // Neither
      },
    );

    test(
      'CategoryLimitProgress evaluates progress fraction and threshold colors correctly',
      () {
        // 50% (< 75% -> Green)
        final p1 = CategoryLimitProgress(
          category: BudgetCategory.expenseCategories.first,
          spent: 250.0,
          limit: 500.0,
        );
        expect(p1.percentage, equals(50.0));
        expect(p1.progressFraction, equals(0.5));
        expect(p1.statusColor, equals(const Color(0xFF10B981)));

        // 80% (75-89% -> Amber)
        final p2 = CategoryLimitProgress(
          category: BudgetCategory.expenseCategories.first,
          spent: 400.0,
          limit: 500.0,
        );
        expect(p2.statusColor, equals(const Color(0xFFF59E0B)));

        // 110% (>= 90% -> Red, progress clamped to 1.0)
        final p3 = CategoryLimitProgress(
          category: BudgetCategory.expenseCategories.first,
          spent: 550.0,
          limit: 500.0,
        );
        expect(p3.percentage, closeTo(110.0, 0.001));
        expect(p3.progressFraction, equals(1.0));
        expect(p3.statusColor, equals(const Color(0xFFEF4444)));
      },
    );

    test(
      'resolveCategoryOnTypeChange preserves common category or falls back to first',
      () {
        // 'other' exists in both Expense and Income
        final preserved = BudgetHelpers.resolveCategoryOnTypeChange(
          currentCategory: 'other',
          newType: TransactionType.income,
        );
        expect(preserved, equals('other'));

        // 'food' only exists in Expense -> switching to Income falls back to first ('salary')
        final fallback = BudgetHelpers.resolveCategoryOnTypeChange(
          currentCategory: 'food',
          newType: TransactionType.income,
        );
        expect(fallback, equals('salary'));
      },
    );
  });

  group('Budget Models Serialization Tests', () {
    test('BudgetTransactionModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 25, 14, 0);
      final model = BudgetTransactionModel(
        id: 'tx_123',
        amount: 85.50,
        type: TransactionType.expense,
        category: 'food',
        date: DateTime(2026, 8, 25),
        note: 'Dinner with friends',
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['amount'], equals(85.50));
      expect(map['type'], equals('expense'));
      expect(map['category'], equals('food'));
      expect(map['note'], equals('Dinner with friends'));

      final deserialized = BudgetTransactionModel.fromMap(map, 'tx_123');
      expect(deserialized.id, equals('tx_123'));
      expect(deserialized.amount, equals(85.50));
      expect(deserialized.type, equals(TransactionType.expense));
      expect(deserialized.isExpense, isTrue);
    });

    test('BudgetConfigModel removes 0 and negative limits on toMap', () {
      const config = BudgetConfigModel(
        limits: {
          'food': 400.0,
          'transport': 0.0,
          'entertainment': -10.0,
          'bills': 250.0,
        },
      );

      final map = config.toMap();
      final limitsMap = map['limits'] as Map<String, dynamic>;
      expect(limitsMap['food'], equals(400.0));
      expect(limitsMap['bills'], equals(250.0));
      expect(limitsMap.containsKey('transport'), isFalse);
      expect(limitsMap.containsKey('entertainment'), isFalse);
    });
  });

  group('Budget Tracker UI & Widget Tests', () {
    final now = DateTime.now();
    final mockTxList = [
      BudgetTransactionModel(
        id: '1',
        amount: 2500.0,
        type: TransactionType.income,
        category: 'salary',
        date: now,
        note: 'Main salary',
        createdAt: now,
        updatedAt: now,
      ),
      BudgetTransactionModel(
        id: '2',
        amount: 120.0,
        type: TransactionType.expense,
        category: 'food',
        date: now,
        note: 'Supermarket',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    const mockConfig = BudgetConfigModel(
      limits: {'food': 300.0, 'transport': 100.0},
    );

    testWidgets(
      'BudgetTrackerPage renders empty state when zero transactions exist',
      (tester) async {
        await tester.pumpWidget(
          createBudgetTestWidget(
            child: const BudgetTrackerPage(),
            overrides: [
              budgetTransactionsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              budgetConfigStreamProvider.overrideWith(
                (ref) => Stream.value(const BudgetConfigModel()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('💰 Start by logging your first transaction'),
          findsOneWidget,
        );
        expect(
          find.text('Add Transaction'),
          findsNWidgets(2),
        ); // FAB and empty state button
      },
    );

    testWidgets(
      'BudgetTrackerPage renders stats, budget limits progress, and recent transactions',
      (tester) async {
        await tester.pumpWidget(
          createBudgetTestWidget(
            child: const BudgetTrackerPage(),
            overrides: [
              budgetTransactionsStreamProvider.overrideWith(
                (ref) => Stream.value(mockTxList),
              ),
              budgetConfigStreamProvider.overrideWith(
                (ref) => Stream.value(mockConfig),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Stats
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('\$2500.00'), findsOneWidget);
        expect(find.text('Expenses'), findsOneWidget);
        expect(find.text('\$120.00'), findsOneWidget);
        expect(find.text('Balance'), findsOneWidget);
        expect(find.text('\$2380.00'), findsOneWidget);

        // Budget Limits Card
        expect(find.text('Budget Limits'), findsOneWidget);
        expect(find.text('Configure Limits'), findsOneWidget);
        expect(find.text('\$120.00 / \$300.00'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsWidgets);

        // Recent Transactions List
        expect(find.text('Recent Transactions'), findsOneWidget);
        expect(find.text('Supermarket'), findsOneWidget);
        expect(find.text('Main salary'), findsOneWidget);
        expect(find.text('+\$2500.00'), findsOneWidget);
        expect(find.text('-\$120.00'), findsOneWidget);
      },
    );

    testWidgets('TransactionFormModal validates amount greater than 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        createBudgetTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TransactionFormModal.show(context),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Add Transaction'), findsOneWidget);

      // Scroll to Save button and tap with empty amount
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than 0'), findsOneWidget);
    });

    testWidgets(
      'BudgetConfigModal displays category inputs and pre-fills limits',
      (tester) async {
        await tester.pumpWidget(
          createBudgetTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    BudgetConfigModal.show(context, initialConfig: mockConfig),
                child: const Text('Open Config'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Config'));
        await tester.pumpAndSettle();

        expect(find.text('Monthly Budget Limits'), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(find.text('Transport'), findsOneWidget);
        expect(find.text('Entertainment'), findsOneWidget);
        expect(find.text('300'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer contains Finance section with Budget Tracker item',
      (tester) async {
        await tester.pumpWidget(
          createBudgetTestWidget(
            child: const HomeScreen(),
            overrides: [
              budgetTransactionsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              budgetConfigStreamProvider.overrideWith(
                (ref) => Stream.value(const BudgetConfigModel()),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        expect(find.text('FINANCE'), findsOneWidget);
        expect(find.text('Budget Tracker'), findsOneWidget);
      },
    );

    testWidgets('Arabic localization renders all Budget Tracker texts', (
      tester,
    ) async {
      await tester.pumpWidget(
        createBudgetTestWidget(
          locale: const Locale('ar'),
          child: const BudgetTrackerPage(),
          overrides: [
            budgetTransactionsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            budgetConfigStreamProvider.overrideWith(
              (ref) => Stream.value(const BudgetConfigModel()),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('متتبع الميزانية'), findsOneWidget);
      expect(find.text('💰 ابدأ بتسجيل أول معاملة مالية'), findsOneWidget);
      expect(find.text('إضافة معاملة'), findsNWidgets(2));
    });
  });
}
