import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/time_audit_model.dart';

/// Service handling Firestore operations for Time Audit manual logs.
///
/// All logs are strictly scoped to the user's isolated subcollection:
/// `users/{uid}/timeAuditLogs/{logId}`
class TimeAuditService {
  final FirebaseFirestore _firestore;

  TimeAuditService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('timeAuditLogs');
  }

  /// Streams all manual time audit logs for [uid] ordered by date descending.
  Stream<List<TimeAuditLogModel>> streamLogs(String uid) {
    return _logsCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TimeAuditLogModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new manual time log entry.
  Future<String?> addLog({
    required String uid,
    required String category,
    required double hours,
    String description = '',
    DateTime? date,
  }) async {
    try {
      if (uid.isEmpty ||
          category.trim().isEmpty ||
          !hours.isFinite ||
          hours <= 0 ||
          hours > 24) {
        throw ArgumentError('Invalid time log');
      }
      final docRef = _logsCollection(uid).doc();
      final now = DateTime.now();
      final entryDate = date ?? now;

      final log = TimeAuditLogModel(
        id: docRef.id,
        category: category,
        hours: hours,
        description: description,
        date: entryDate,
        createdAt: now,
      );

      await docRef.set(log.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding time audit log: $e');
      return null;
    }
  }

  /// Deletes a specific time audit log entry.
  Future<bool> deleteLog({required String uid, required String logId}) async {
    try {
      await _logsCollection(uid).doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting time audit log: $e');
      return false;
    }
  }

  /// Clears all manual time audit logs for the user.
  Future<bool> clearAllLogs(String uid) async {
    try {
      while (true) {
        final snapshot = await _logsCollection(uid).limit(200).get();
        if (snapshot.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing all time audit logs: $e');
      return false;
    }
  }
}
