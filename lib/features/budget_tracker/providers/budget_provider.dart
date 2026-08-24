import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/budget_helpers.dart';
import '../models/budget_models.dart';
import '../services/budget_service.dart';

/// Singleton provider for BudgetService.
final budgetServiceProvider = Provider<BudgetService>((ref) {
  return BudgetService();
});

/// Stream provider for all budget transactions belonging to the current user.
final budgetTransactionsStreamProvider =
    StreamProvider<List<BudgetTransactionModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(budgetServiceProvider);
  return service.streamTransactions(uid);
});

/// Stream provider for the user's budget spending limits configuration.
final budgetConfigStreamProvider = StreamProvider<BudgetConfigModel>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(budgetServiceProvider);
  return service.streamBudgetConfig(uid);
});

/// Derived provider: Transactions occurring in the current calendar month.
final thisMonthTransactionsProvider =
    Provider<List<BudgetTransactionModel>>((ref) {
  final allTx = ref.watch(budgetTransactionsStreamProvider).value ?? [];
  return BudgetHelpers.filterThisMonthTransactions(allTx, DateTime.now());
});

/// Derived provider: Income, Expenses, and Balance totals for this month.
final thisMonthSummaryProvider = Provider<MonthSummary>((ref) {
  final thisMonthTx = ref.watch(thisMonthTransactionsProvider);
  return BudgetHelpers.computeMonthSummary(thisMonthTx);
});

/// Derived provider: Total spending per expense category for this month.
final thisMonthCategorySpendingProvider =
    Provider<Map<String, double>>((ref) {
  final thisMonthTx = ref.watch(thisMonthTransactionsProvider);
  return BudgetHelpers.computeCategorySpending(thisMonthTx);
});

/// Derived provider: 10 most recent transactions reverse-chronologically across all time.
final recentTransactionsProvider =
    Provider<List<BudgetTransactionModel>>((ref) {
  final allTx = ref.watch(budgetTransactionsStreamProvider).value ?? [];
  final sorted = List<BudgetTransactionModel>.from(allTx)
    ..sort((a, b) => b.date.compareTo(a.date));
  return sorted.take(10).toList();
});

/// Derived provider: Progress and limits list for relevant expense categories.
final categoryLimitProgressListProvider =
    Provider<List<CategoryLimitProgress>>((ref) {
  final spending = ref.watch(thisMonthCategorySpendingProvider);
  final config = ref.watch(budgetConfigStreamProvider).value ?? const BudgetConfigModel();
  return BudgetHelpers.getRelevantExpenseCategories(
    spending: spending,
    limits: config.limits,
  );
});
