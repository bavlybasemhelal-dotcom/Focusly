import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Transaction type: income vs expense.
enum TransactionType {
  income,
  expense;

  String get id => name;

  static TransactionType fromString(String? val) {
    if (val == 'income') return TransactionType.income;
    return TransactionType.expense;
  }
}

/// Category metadata defining icon, emoji, translation key, and type.
class BudgetCategory {
  final String id;
  final String labelKey;
  final String emoji;
  final IconData icon;
  final TransactionType type;

  const BudgetCategory({
    required this.id,
    required this.labelKey,
    required this.emoji,
    required this.icon,
    required this.type,
  });

  /// All fixed Expense categories.
  static const List<BudgetCategory> expenseCategories = [
    BudgetCategory(
      id: 'food',
      labelKey: 'cat_food',
      emoji: '🍔',
      icon: Icons.fastfood_rounded,
      type: TransactionType.expense,
    ),
    BudgetCategory(
      id: 'transport',
      labelKey: 'cat_transport',
      emoji: '🚗',
      icon: Icons.directions_car_rounded,
      type: TransactionType.expense,
    ),
    BudgetCategory(
      id: 'entertainment',
      labelKey: 'cat_entertainment',
      emoji: '🎬',
      icon: Icons.movie_rounded,
      type: TransactionType.expense,
    ),
    BudgetCategory(
      id: 'bills',
      labelKey: 'cat_bills',
      emoji: '🧾',
      icon: Icons.receipt_long_rounded,
      type: TransactionType.expense,
    ),
    BudgetCategory(
      id: 'education',
      labelKey: 'cat_education',
      emoji: '📚',
      icon: Icons.school_rounded,
      type: TransactionType.expense,
    ),
    BudgetCategory(
      id: 'other',
      labelKey: 'cat_other',
      emoji: '📦',
      icon: Icons.category_rounded,
      type: TransactionType.expense,
    ),
  ];

  /// All fixed Income categories.
  static const List<BudgetCategory> incomeCategories = [
    BudgetCategory(
      id: 'salary',
      labelKey: 'cat_salary',
      emoji: '💼',
      icon: Icons.work_rounded,
      type: TransactionType.income,
    ),
    BudgetCategory(
      id: 'freelance',
      labelKey: 'cat_freelance',
      emoji: '💻',
      icon: Icons.laptop_mac_rounded,
      type: TransactionType.income,
    ),
    BudgetCategory(
      id: 'investment',
      labelKey: 'cat_investment',
      emoji: '📈',
      icon: Icons.trending_up_rounded,
      type: TransactionType.income,
    ),
    BudgetCategory(
      id: 'gift',
      labelKey: 'cat_gift',
      emoji: '🎁',
      icon: Icons.card_giftcard_rounded,
      type: TransactionType.income,
    ),
    BudgetCategory(
      id: 'other',
      labelKey: 'cat_other',
      emoji: '📦',
      icon: Icons.category_rounded,
      type: TransactionType.income,
    ),
  ];

  /// Finds category metadata by ID and type.
  static BudgetCategory find(String categoryId, TransactionType type) {
    final list = type == TransactionType.expense
        ? expenseCategories
        : incomeCategories;
    try {
      return list.firstWhere((c) => c.id == categoryId);
    } catch (_) {
      return list.last; // Fallback to 'other'
    }
  }
}

/// Model representing a single Income or Expense transaction.
///
/// Firestore path: `users/{userId}/budgetTransactions/{txId}`
class BudgetTransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetTransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  /// Converts model to Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'type': type.id,
      'category': category,
      'date': Timestamp.fromDate(date),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore snapshot map.
  factory BudgetTransactionModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    final type = TransactionType.fromString(map['type'] as String?);
    final category = (map['category'] as String?)?.trim() ?? 'other';
    final date = parseDate(map['date'], now);
    final note = (map['note'] as String?)?.trim();
    final createdAt = parseDate(map['createdAt'], date);
    final updatedAt = parseDate(map['updatedAt'], createdAt);

    return BudgetTransactionModel(
      id: docId,
      amount: amount,
      type: type,
      category: category,
      date: date,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  BudgetTransactionModel copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetTransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BudgetTransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          amount == other.amount &&
          type == other.type &&
          category == other.category &&
          date.year == other.date.year &&
          date.month == other.date.month &&
          date.day == other.date.day &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      amount.hashCode ^
      type.hashCode ^
      category.hashCode ^
      date.hashCode ^
      note.hashCode;
}

/// Model representing the monthly spending limits configuration.
///
/// Firestore path: `users/{userId}/budgetConfig/main` (single document)
class BudgetConfigModel {
  final Map<String, double> limits;

  const BudgetConfigModel({this.limits = const {}});

  /// Converts to Firestore map (only contains keys with limit > 0).
  Map<String, dynamic> toMap() {
    final cleanLimits = <String, dynamic>{};
    limits.forEach((key, value) {
      if (value > 0) {
        cleanLimits[key] = value;
      }
    });
    return {'limits': cleanLimits};
  }

  /// Deserializes Firestore document map.
  factory BudgetConfigModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BudgetConfigModel();
    final rawLimits = map['limits'] as Map<String, dynamic>? ?? {};
    final cleanLimits = <String, double>{};
    rawLimits.forEach((k, v) {
      if (v is num && v > 0) {
        cleanLimits[k] = v.toDouble();
      }
    });
    return BudgetConfigModel(limits: cleanLimits);
  }
}
