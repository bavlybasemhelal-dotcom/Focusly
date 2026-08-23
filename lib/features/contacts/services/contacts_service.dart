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
    return _contactsCollection(uid)
        .orderBy('name')
        .snapshots()
        .map((snap) {
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
        contactInfo: contactInfo?.trim().isNotEmpty == true ? contactInfo!.trim() : null,
        lastContact: lastContact ?? now,
        remindDays: remindDays > 0 ? remindDays : 30,
        notes: notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(contact.toMap());
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
      await _contactsCollection(uid).doc(contact.id).set(
            updated.toMap(),
            SetOptions(merge: true),
          );
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
      await _contactsCollection(uid).doc(contactId).delete();
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
      final now = DateTime.now();
      await _contactsCollection(uid).doc(contactId).set(
        {
          'lastContact': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking contact as contacted today: $e');
      return false;
    }
  }
}
