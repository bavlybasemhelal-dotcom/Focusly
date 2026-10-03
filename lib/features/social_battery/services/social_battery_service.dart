import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/social_battery_entry_model.dart';

/// Service managing Firestore operations for the Social Battery feature.
///
/// Documents are isolated per user under `users/{uid}/socialBattery/{entryId}`.
class SocialBatteryService {
  final FirebaseFirestore _firestore;

  SocialBatteryService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _batteryCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('socialBattery');
  }

  /// Streams all Social Battery entries for [uid] ordered by date descending.
  Stream<List<SocialBatteryEntryModel>> streamEntries(String uid) {
    return _batteryCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SocialBatteryEntryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new Social Battery entry.
  Future<String?> addEntry({
    required String uid,
    required String name,
    required String type,
    int impact = 3,
    required DateTime date,
    String? notes,
  }) async {
    try {
      final docRef = _batteryCollection(uid).doc();
      final now = DateTime.now();

      final entry = SocialBatteryEntryModel(
        id: docRef.id,
        name: name.trim(),
        type: (type.toLowerCase() == 'drainer') ? 'drainer' : 'energizer',
        impact: impact.clamp(1, 5),
        date: date,
        notes: (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(entry.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding social battery entry: $e');
      return null;
    }
  }

  /// Updates an existing Social Battery entry.
  Future<bool> updateEntry({
    required String uid,
    required SocialBatteryEntryModel currentEntry,
    required String newName,
    required String newType,
    required int newImpact,
    required DateTime newDate,
    String? newNotes,
  }) async {
    try {
      final now = DateTime.now();
      final updated = currentEntry.copyWith(
        name: newName.trim(),
        type: (newType.toLowerCase() == 'drainer') ? 'drainer' : 'energizer',
        impact: newImpact.clamp(1, 5),
        date: newDate,
        notes: newNotes != null && newNotes.trim().isNotEmpty
            ? newNotes.trim()
            : null,
        clearNotes: newNotes == null || newNotes.trim().isEmpty,
        updatedAt: now,
      );

      await _batteryCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating social battery entry: $e');
      return false;
    }
  }

  /// Deletes a Social Battery entry.
  Future<bool> deleteEntry({
    required String uid,
    required String entryId,
  }) async {
    try {
      await _batteryCollection(uid).doc(entryId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting social battery entry: $e');
      return false;
    }
  }
}
