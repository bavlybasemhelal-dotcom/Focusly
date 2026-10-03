import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/knowledge_entry_model.dart';

/// Service managing Firestore operations for the personal Knowledge Base feature.
///
/// Documents are isolated per user under `users/{uid}/knowledge/{entryId}`.
class KnowledgeBaseService {
  final FirebaseFirestore _firestore;

  KnowledgeBaseService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _knowledgeCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('knowledge');
  }

  /// Streams all knowledge entries for [uid] ordered by updatedAt descending.
  Stream<List<KnowledgeEntryModel>> streamEntries(String uid) {
    return _knowledgeCollection(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => KnowledgeEntryModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new knowledge entry.
  Future<String?> addEntry({
    required String uid,
    required String title,
    required String type,
    required String content,
    String? source,
    List<String> tags = const [],
  }) async {
    try {
      final docRef = _knowledgeCollection(uid).doc();
      final now = DateTime.now();

      final entry = KnowledgeEntryModel(
        id: docRef.id,
        title: title.trim(),
        type: type.trim(),
        content: content.trim(),
        source: (source != null && source.trim().isNotEmpty)
            ? source.trim()
            : null,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(entry.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding knowledge entry: $e');
      return null;
    }
  }

  /// Updates an existing knowledge entry.
  Future<bool> updateEntry({
    required String uid,
    required KnowledgeEntryModel entry,
  }) async {
    try {
      final now = DateTime.now();
      final updated = entry.copyWith(updatedAt: now);

      await _knowledgeCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating knowledge entry: $e');
      return false;
    }
  }

  /// Deletes a knowledge entry.
  Future<bool> deleteEntry({
    required String uid,
    required String entryId,
  }) async {
    try {
      await _knowledgeCollection(uid).doc(entryId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting knowledge entry: $e');
      return false;
    }
  }
}
