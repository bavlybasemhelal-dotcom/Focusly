import '../../../core/data/contact_history_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/relationship_log_model.dart';

/// Service managing Firestore operations for the Relationship Health feature.
///
/// Documents are isolated per user under `users/{uid}/relationshipLogs/{logId}`.
class RelationshipHealthService {
  final FirebaseFirestore _firestore;

  RelationshipHealthService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsCollection(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('relationshipLogs');
  }

  /// Streams all relationship interaction logs for [uid] ordered by date descending.
  Stream<List<RelationshipLogModel>> streamLogs(String uid) {
    return _logsCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RelationshipLogModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new relationship interaction log and updates the linked contact's lastContact date.
  Future<String?> addLog({
    required String uid,
    required String contactId,
    required DateTime date,
    int rating = 5,
    String? notes,
  }) async {
    try {
      final docRef = _logsCollection(uid).doc();
      final now = DateTime.now();

      final log = RelationshipLogModel(
        id: docRef.id,
        contactId: contactId.trim(),
        date: date,
        rating: rating.clamp(1, 5),
        notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      if (contactId.trim().isEmpty || rating < 1 || rating > 5) {
        throw ArgumentError("Invalid interaction");
      }
      await ContactHistoryService(
        _firestore,
      ).mutate(uid, docRef.id, log.toMap());

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding relationship log: $e');
      return null;
    }
  }

  /// Updates an existing relationship interaction log.
  Future<bool> updateLog({
    required String uid,
    required RelationshipLogModel currentLog,
    required String newContactId,
    required DateTime newDate,
    required int newRating,
    String? newNotes,
  }) async {
    try {
      final now = DateTime.now();
      final updated = currentLog.copyWith(
        contactId: newContactId.trim(),
        date: newDate,
        rating: newRating.clamp(1, 5),
        notes: newNotes != null && newNotes.trim().isNotEmpty
            ? newNotes.trim()
            : null,
        clearNotes: newNotes == null || newNotes.trim().isEmpty,
        updatedAt: now,
      );

      if (newContactId.trim().isEmpty || newRating < 1 || newRating > 5) {
        throw ArgumentError("Invalid interaction");
      }
      await ContactHistoryService(
        _firestore,
      ).mutate(uid, updated.id, updated.toMap(), mustExist: true);

      return true;
    } catch (e) {
      debugPrint('Error updating relationship log: $e');
      return false;
    }
  }

  /// Deletes a relationship interaction log.
  Future<bool> deleteLog({required String uid, required String logId}) async {
    try {
      await ContactHistoryService(
        _firestore,
      ).mutate(uid, logId, null, mustExist: true);
      return true;
    } catch (e) {
      debugPrint('Error deleting relationship log: $e');
      return false;
    }
  }
}
