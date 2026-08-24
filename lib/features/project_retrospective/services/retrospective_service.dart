import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/retrospective_model.dart';

/// Service handling Firestore operations for Project Retrospectives.
///
/// Documents are isolated per user under:
/// `users/{uid}/retrospectives/{retroId}`
class RetrospectiveService {
  final FirebaseFirestore _firestore;

  RetrospectiveService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _retrosCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('retrospectives');
  }

  /// Streams all retrospectives for the specified user [uid], ordered by date descending.
  Stream<List<RetrospectiveModel>> streamRetrospectives(String uid) {
    return _retrosCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RetrospectiveModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new project retrospective document.
  Future<String?> addRetrospective({
    required String uid,
    required String projectId,
    required DateTime date,
    required String wentWell,
    required String toImprove,
    required String learnings,
  }) async {
    try {
      final docRef = _retrosCollection(uid).doc();
      final now = DateTime.now();

      final retro = RetrospectiveModel(
        id: docRef.id,
        projectId: projectId.trim(),
        date: date,
        wentWell: wentWell.trim(),
        toImprove: toImprove.trim(),
        learnings: learnings.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(retro.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding project retrospective: $e');
      return null;
    }
  }

  /// Updates an existing project retrospective document.
  Future<bool> updateRetrospective({
    required String uid,
    required RetrospectiveModel retrospective,
  }) async {
    try {
      final now = DateTime.now();
      final updated = retrospective.copyWith(updatedAt: now);
      await _retrosCollection(uid).doc(retrospective.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating project retrospective: $e');
      return false;
    }
  }

  /// Deletes a specific retrospective document.
  Future<bool> deleteRetrospective({
    required String uid,
    required String retrospectiveId,
  }) async {
    try {
      await _retrosCollection(uid).doc(retrospectiveId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting project retrospective: $e');
      return false;
    }
  }
}
