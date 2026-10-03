import '../../relationship_health/services/relationship_health_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/contact_model.dart';

/// Service managing Firestore operations for the Personal CRM (Contacts) feature.
///
/// Strictly scoped to `users/{uid}/contacts/{contactId}`.
class ContactsService {
  final FirebaseFirestore _firestore;

  ContactsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('contacts');
  }

  /// Returns real-time stream of all contacts for a user.
  Stream<List<ContactModel>> streamContacts(String uid) {
    return _contactsCollection(uid).orderBy('name').snapshots().map((snap) {
      return snap.docs
          .map((doc) => ContactModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new contact in Firestore.
  Future<String?> addContact({
    required String uid,
    required String name,
    String emoji = '🙂',
    String? role,
    String? contactInfo,
    DateTime? lastContact,
    int remindDays = 30,
    String? notes,
  }) async {
    try {
      final docRef = _contactsCollection(uid).doc();
      final now = DateTime.now();
      final contact = ContactModel(
        id: docRef.id,
        name: name.trim(),
        emoji: emoji.trim().isNotEmpty ? emoji.trim() : '🙂',
        role: role?.trim().isNotEmpty == true ? role!.trim() : null,
        contactInfo: contactInfo?.trim().isNotEmpty == true
            ? contactInfo!.trim()
            : null,
        lastContact: lastContact ?? now,
        remindDays: remindDays > 0 ? remindDays : 30,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      if (name.trim().isEmpty || remindDays < 1 || remindDays > 3650) {
        throw ArgumentError('Invalid contact');
      }
      final batch = _firestore.batch();
      batch.set(docRef, {
        ...contact.toMap(),
        'hasContacted': lastContact != null,
        'lastContact': lastContact == null
            ? null
            : Timestamp.fromDate(lastContact),
      });
      if (lastContact != null) {
        final log = _firestore
            .collection('users')
            .doc(uid)
            .collection('relationshipLogs')
            .doc('initial_${docRef.id}');
        batch.set(log, {
          'contactId': docRef.id,
          'date': Timestamp.fromDate(lastContact),
          'rating': 5,
          'notes': null,
          'createdAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
      await batch.commit();
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding contact: $e');
      return null;
    }
  }

  /// Updates an existing contact.
  Future<bool> updateContact({
    required String uid,
    required ContactModel contact,
  }) async {
    try {
      final now = DateTime.now();
      final updated = contact.copyWith(updatedAt: now);
      final data = updated.toMap()
        ..remove('lastContact')
        ..remove('hasContacted')
        ..remove('createdAt');
      await _contactsCollection(uid).doc(contact.id).update(data);
      return true;
    } catch (e) {
      debugPrint('Error updating contact: $e');
      return false;
    }
  }

  /// Deletes a contact document.
  Future<bool> deleteContact({
    required String uid,
    required String contactId,
  }) async {
    try {
      final contact = _contactsCollection(uid).doc(contactId);
      await contact.update({'deletionPending': true});
      while (true) {
        final logs = await _firestore
            .collection('users')
            .doc(uid)
            .collection('relationshipLogs')
            .where('contactId', isEqualTo: contactId)
            .limit(200)
            .get();
        if (logs.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final log in logs.docs) {
          batch.delete(log.reference);
        }
        await batch.commit();
      }
      await contact.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting contact: $e');
      return false;
    }
  }

  /// Quickly updates lastContact to today.
  Future<bool> markContactedToday({
    required String uid,
    required String contactId,
  }) async {
    try {
      final result = await RelationshipHealthService(
        firestore: _firestore,
      ).addLog(uid: uid, contactId: contactId, date: DateTime.now());
      if (result == null) return false;
      return true;
    } catch (e) {
      debugPrint('Error marking contact as contacted today: $e');
      return false;
    }
  }
}
