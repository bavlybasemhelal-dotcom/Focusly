import 'package:flutter/material.dart';
import '../models/budget_models.dart';

/// Container for monthly income, expenses, and balance summary.
class MonthSummary {
  final double totalIncome;
  final double totalExpenses;
  final double balance;

  const MonthSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.balance,
  });

  String formatCurrency(double val, {bool showSign = false}) {
    final absVal = val.abs();
    final formatted = absVal.toStringAsFixed(2);
    if (showSign) {
      if (val > 0) return '+\$$formatted';
      if (val < 0) return '-\$$formatted';
      return '\$$formatted';
    }
    return '\$$formatted';
  }
}

/// Item representing an expense category limit and spent progress for the UI.
class CategoryLimitProgress {
  final BudgetCategory category;
  final double spent;
  final double? limit; // null if no limit configured

  const CategoryLimitProgress({
    required this.category,
    required this.spent,
    this.limit,
  });

  bool get hasLimit => limit != null && limit! > 0;

  /// Visual progress fraction clamped to 1.0 (100%).
  double get progressFraction {
    if (!hasLimit) return 0.0;
    return (spent / limit!).clamp(0.0, 1.0);
  }

  /// Exact spending percentage of limit.
  double get percentage {
    if (!hasLimit) return 0.0;
    return (spent / limit!) * 100.0;
  }

  /// Status color based on threshold rules:
  /// - < 75%: Green
  /// - 75% to 89%: Amber
  /// - >= 90%: Red
  Color get statusColor {
    if (!hasLimit) return const Color(0xFF10B981);
    if (percentage < 75.0) return const Color(0xFF10B981);
    if (percentage < 90.0) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

/// Pure helper functions for budget aggregations, limits filtering, and category selection.
class BudgetHelpers {
  /// Filters transactions for the specified calendar month (`targetMonth.year` and `targetMonth.month`).
  static List<BudgetTransactionModel> filterThisMonthTransactions(
    List<BudgetTransactionModel> allTx,
    DateTime targetMonth,
  ) {
    return allTx.where((tx) {
      return tx.date.year == targetMonth.year && tx.date.month == targetMonth.month;
    }).toList();
  }

  /// Computes monthly income, expenses, and net balance.
  static MonthSummary computeMonthSummary(List<BudgetTransactionModel> thisMonthTx) {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final tx in thisMonthTx) {
      if (tx.isIncome) {
        totalIncome += tx.amount;
      } else if (tx.isExpense) {
        totalExpenses += tx.amount;
      }
    }

    return MonthSummary(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      balance: totalIncome - totalExpenses,
    );
  }

  /// Computes total spending per expense category for this month.
  static Map<String, double> computeCategorySpending(
    List<BudgetTransactionModel> thisMonthTx,
  ) {
    final spending = <String, double>{};
    for (final tx in thisMonthTx) {
      if (tx.isExpense) {
        spending[tx.category] = (spending[tx.category] ?? 0.0) + tx.amount;
      }
    }
    return spending;
  }

  /// Filters expense categories to only those that have EITHER a configured limit OR spending this month.
  static List<CategoryLimitProgress> getRelevantExpenseCategories({
    required Map<String, double> spending,
    required Map<String, double> limits,
  }) {
    final results = <CategoryLimitProgress>[];

    for (final cat in BudgetCategory.expenseCategories) {
      final spent = spending[cat.id] ?? 0.0;
      final limit = limits[cat.id];
      final hasLimit = limit != null && limit > 0;

      // Only show if spending > 0 OR limit > 0
      if (spent > 0 || hasLimit) {
        results.add(
          CategoryLimitProgress(
            category: cat,
            spent: spent,
            limit: hasLimit ? limit : null,
          ),
        );
      }
    }

    return results;
  }

  /// Resolves the category ID when switching between Income and Expense types,
  /// preserving previous selection if it exists in the new list, or defaulting to first.
  static String resolveCategoryOnTypeChange({
    required String currentCategory,
    required TransactionType newType,
  }) {
    final targetList = newType == TransactionType.expense
        ? BudgetCategory.expenseCategories
        : BudgetCategory.incomeCategories;

    final exists = targetList.any((c) => c.id == currentCategory);
    if (exists) {
      return currentCategory;
    }
    return targetList.first.id;
  }
}
