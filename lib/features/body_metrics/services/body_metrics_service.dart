import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../helpers/body_metrics_helpers.dart';
import '../models/body_metric_model.dart';

/// Service managing Firestore operations for the Body Metrics feature.
///
/// Documents are isolated per-user under `users/{uid}/bodyMetrics/{metricId}`.
class BodyMetricsService {
  final FirebaseFirestore _firestore;

  BodyMetricsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _metricsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('bodyMetrics');
  }

  /// Streams all body metrics for [uid] ordered by date descending.
  Stream<List<BodyMetricModel>> streamBodyMetrics(String uid) {
    return _metricsCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BodyMetricModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new body metric entry.
  Future<String?> addMetric({
    required String uid,
    required DateTime date,
    double? weight,
    int? bpSystolic,
    int? bpDiastolic,
    int? pulse,
    String? note,
  }) async {
    try {
      final docRef = _metricsCollection(uid).doc();
      final now = DateTime.now();

      final metric = BodyMetricModel(
        id: docRef.id,
        date: BodyMetricsHelpers.toDateOnly(date),
        weight: (weight != null && weight.isFinite && weight > 0)
            ? weight
            : null,
        bpSystolic: (bpSystolic != null && bpSystolic > 0) ? bpSystolic : null,
        bpDiastolic: (bpDiastolic != null && bpDiastolic > 0)
            ? bpDiastolic
            : null,
        pulse: (pulse != null && pulse > 0) ? pulse : null,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(metric.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding body metric: $e');
      return null;
    }
  }

  /// Updates an existing body metric entry.
  Future<bool> updateMetric({
    required String uid,
    required BodyMetricModel currentMetric,
    required DateTime newDate,
    double? newWeight,
    int? newBpSystolic,
    int? newBpDiastolic,
    int? newPulse,
    String? newNote,
  }) async {
    try {
      final now = DateTime.now();
      final updated = currentMetric.copyWith(
        date: BodyMetricsHelpers.toDateOnly(newDate),
        weight: (newWeight != null && newWeight.isFinite && newWeight > 0)
            ? newWeight
            : null,
        clearWeight: newWeight == null || !newWeight.isFinite || newWeight <= 0,
        bpSystolic: (newBpSystolic != null && newBpSystolic > 0)
            ? newBpSystolic
            : null,
        bpDiastolic: (newBpDiastolic != null && newBpDiastolic > 0)
            ? newBpDiastolic
            : null,
        clearBp:
            newBpSystolic == null ||
            newBpSystolic <= 0 ||
            newBpDiastolic == null ||
            newBpDiastolic <= 0,
        pulse: (newPulse != null && newPulse > 0) ? newPulse : null,
        clearPulse: newPulse == null || newPulse <= 0,
        note: (newNote != null && newNote.trim().isNotEmpty)
            ? newNote.trim()
            : null,
        clearNote: newNote == null || newNote.trim().isEmpty,
        updatedAt: now,
      );

      await _metricsCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating body metric: $e');
      return false;
    }
  }

  /// Deletes a body metric entry.
  Future<bool> deleteMetric({
    required String uid,
    required String metricId,
  }) async {
    try {
      await _metricsCollection(uid).doc(metricId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting body metric: $e');
      return false;
    }
  }
}
