import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/budget_models.dart';

/// Firestore service for the Budget Tracker feature.
///
/// Data paths (per-user data isolation):
/// - `users/{uid}/budgetTransactions/{txId}`
/// - `users/{uid}/budgetConfig/main`
class BudgetService {
  final FirebaseFirestore _firestore;

  BudgetService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _txCollection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgetTransactions');
  }

  DocumentReference<Map<String, dynamic>> _configDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgetConfig')
        .doc('main');
  }

  /// Streams all budget transactions for [uid] ordered by date descending.
  Stream<List<BudgetTransactionModel>> streamTransactions(String uid) {
    return _txCollection(uid).orderBy('date', descending: true).snapshots().map(
      (snapshot) {
        return snapshot.docs
            .map((doc) => BudgetTransactionModel.fromMap(doc.data(), doc.id))
            .toList();
      },
    );
  }

  /// Streams the budget config document for [uid].
  Stream<BudgetConfigModel> streamBudgetConfig(String uid) {
    return _configDoc(uid).snapshots().map((snapshot) {
      return BudgetConfigModel.fromMap(snapshot.data());
    });
  }

  /// Adds a new income/expense transaction.
  Future<String?> addTransaction({
    required String uid,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    if (uid.isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        category.trim().isEmpty) {
      return null;
    }
    try {
      final docRef = _txCollection(uid).doc();
      final now = DateTime.now();

      final model = BudgetTransactionModel(
        id: docRef.id,
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: note,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(model.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding budget transaction: $e');
      return null;
    }
  }

  /// Updates an existing transaction.
  Future<bool> updateTransaction({
    required String uid,
    required String id,
    required double amount,
    required TransactionType type,
    required String category,
    required DateTime date,
    String? note,
  }) async {
    if (uid.isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        category.trim().isEmpty) {
      return false;
    }
    try {
      final docRef = _txCollection(uid).doc(id);
      final existing = await docRef.get();
      final now = DateTime.now();
      final createdAt = existing.exists && existing.data()?['createdAt'] != null
          ? (existing.data()!['createdAt'] is Timestamp
                ? (existing.data()!['createdAt'] as Timestamp).toDate()
                : now)
          : now;

      final model = BudgetTransactionModel(
        id: id,
        amount: amount,
        type: type,
        category: category,
        date: date,
        note: note,
        createdAt: createdAt,
        updatedAt: now,
      );

      await docRef.update(model.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating budget transaction: $e');
      return false;
    }
  }

  /// Deletes a transaction.
  Future<bool> deleteTransaction({
    required String uid,
    required String id,
  }) async {
    try {
      await _txCollection(uid).doc(id).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting budget transaction: $e');
      return false;
    }
  }

  /// Saves or updates monthly spending limits in budget config.
  /// (Only categories with limit > 0 are stored).
  Future<bool> saveBudgetConfig({
    required String uid,
    required Map<String, double> limits,
  }) async {
    try {
      final config = BudgetConfigModel(limits: limits);
      await _configDoc(uid).set(config.toMap(), SetOptions(merge: false));
      return true;
    } catch (e) {
      debugPrint('Error saving budget config: $e');
      return false;
    }
  }
}
