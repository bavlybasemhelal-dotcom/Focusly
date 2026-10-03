import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/mental_log_model.dart';

/// Service managing Firestore operations for the Mental Health feature.
///
/// Documents are isolated per-user under `users/{uid}/mentalLog/{dateKey}`.
class MentalHealthService {
  final FirebaseFirestore _firestore;

  MentalHealthService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _mentalCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('mentalLog');
  }

  /// Streams all mental logs for [uid] ordered by date descending.
  Stream<List<MentalLogModel>> streamMentalLogs(String uid) {
    return _mentalCollection(
      uid,
    ).orderBy('weekOf', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => MentalLogModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Upserts a daily mental wellbeing log for [dateKey] (`YYYY-MM-DD`).
  Future<String?> upsertMentalLog({
    required String uid,
    required String dateKey,
    required int anxiety,
    required int happiness,
    required int socialEnergy,
    required int selfSatisfaction,
    required int balance,
  }) async {
    try {
      final docRef = _mentalCollection(uid).doc(dateKey);
      final now = DateTime.now();

      // Check if doc already exists to preserve original createdAt
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

      final log = MentalLogModel(
        id: dateKey,
        weekOf: dateKey,
        anxiety: anxiety.clamp(1, 10),
        happiness: happiness.clamp(1, 10),
        socialEnergy: socialEnergy.clamp(1, 10),
        selfSatisfaction: selfSatisfaction.clamp(1, 10),
        balance: balance.clamp(1, 10),
        createdAt: createdAt,
        updatedAt: now,
      );

      await docRef.set(log.toMap(), SetOptions(merge: true));
      return dateKey;
    } catch (e) {
      debugPrint('Error upserting mental log: $e');
      return null;
    }
  }

  /// Deletes a mental log entry.
  Future<bool> deleteMentalLog({
    required String uid,
    required String docId,
  }) async {
    try {
      await _mentalCollection(uid).doc(docId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting mental log: $e');
      return false;
    }
  }
}
