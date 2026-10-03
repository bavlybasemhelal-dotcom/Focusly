import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../helpers/nutrition_log_helpers.dart';
import '../models/nutrition_log_model.dart';

/// Service managing Firestore operations for the Nutrition Log feature.
///
/// Documents are isolated per-user under `users/{uid}/nutritionLog/{logId}`.
/// Employs date-based upserting so each user has at most one log entry per calendar day.
class NutritionLogService {
  final FirebaseFirestore _firestore;

  NutritionLogService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _nutritionCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('nutritionLog');
  }

  /// Streams all nutrition log entries for [uid] ordered by date descending.
  Stream<List<NutritionLogModel>> streamNutritionLogs(String uid) {
    return _nutritionCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NutritionLogModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Upserts a nutrition log entry for [uid].
  ///
  /// If an entry already exists for [date] (identified by date key `YYYY-MM-DD`),
  /// it updates that existing document instead of creating a duplicate.
  Future<String?> upsertNutritionLog({
    required String uid,
    required int rating,
    required DateTime date,
    String? note,
    String? existingDocId,
  }) async {
    try {
      final now = DateTime.now();
      final dateKey = NutritionLogHelpers.formatDateKey(date);
      final targetDocId = dateKey;
      final docRef = _nutritionCollection(uid).doc(targetDocId);

      // Check if document already exists
      final existingDoc = await docRef.get();
      final DateTime createdAt =
          existingDoc.exists && existingDoc.data()?['createdAt'] != null
          ? (existingDoc.data()!['createdAt'] is Timestamp
                ? (existingDoc.data()!['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse(
                        existingDoc.data()!['createdAt'].toString(),
                      ) ??
                      now)
          : now;

      final normalizedDate = NutritionLogHelpers.toDateOnly(date);

      final log = NutritionLogModel(
        id: targetDocId,
        rating: rating.clamp(1, 5),
        date: normalizedDate,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        createdAt: createdAt,
        updatedAt: now,
      );

      await _firestore.runTransaction((transaction) async {
        final target = await transaction.get(docRef);
        final moved = existingDocId != null && existingDocId != dateKey;
        final source = moved
            ? _nutritionCollection(uid).doc(existingDocId)
            : null;
        if (source != null) {
          final original = await transaction.get(source);
          if (!original.exists) {
            throw StateError('The original log no longer exists');
          }
          if (target.exists) {
            throw StateError('The destination day already has a log');
          }
          transaction.delete(source);
        }
        transaction.set(docRef, log.toMap(), SetOptions(merge: true));
      });
      return targetDocId;
    } catch (e) {
      debugPrint('Error upserting nutrition log: $e');
      return null;
    }
  }

  /// Deletes a nutrition log entry by its [logId].
  Future<bool> deleteNutritionLog({
    required String uid,
    required String logId,
  }) async {
    try {
      await _nutritionCollection(uid).doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting nutrition log: $e');
      return false;
    }
  }
}
