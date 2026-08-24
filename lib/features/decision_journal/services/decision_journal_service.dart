import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/decision_model.dart';

/// Service handling Firestore CRUD operations for the Decision Journal feature.
///
/// All decision documents are strictly isolated per user under:
/// `users/{uid}/decisions/{decisionId}`
class DecisionJournalService {
  final FirebaseFirestore _firestore;

  DecisionJournalService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Returns the isolated Firestore collection reference for the given [uid].
  CollectionReference<Map<String, dynamic>> _decisionsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('decisions');
  }

  /// Streams all decisions for the specified [uid], ordered by date descending.
  Stream<List<DecisionModel>> streamDecisions(String uid) {
    return _decisionsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => DecisionModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new decision entry in Firestore.
  Future<String?> addDecision({
    required String uid,
    required String title,
    required DateTime date,
    required String rationale,
    required String expected,
    String outcome = '',
    bool reviewed = false,
  }) async {
    try {
      final docRef = _decisionsCollection(uid).doc();
      final now = DateTime.now();

      final decision = DecisionModel(
        id: docRef.id,
        title: title.trim(),
        date: date,
        rationale: rationale.trim(),
        expected: expected.trim(),
        outcome: outcome.trim(),
        reviewed: reviewed,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(decision.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding decision log: $e');
      return null;
    }
  }

  /// Updates an existing decision entry in Firestore.
  Future<bool> updateDecision({
    required String uid,
    required DecisionModel decision,
  }) async {
    try {
      final now = DateTime.now();
      final updated = decision.copyWith(updatedAt: now);
      await _decisionsCollection(uid).doc(decision.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating decision log: $e');
      return false;
    }
  }

  /// Deletes a specific decision entry from Firestore.
  Future<bool> deleteDecision({
    required String uid,
    required String decisionId,
  }) async {
    try {
      await _decisionsCollection(uid).doc(decisionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting decision log: $e');
      return false;
    }
  }
}
