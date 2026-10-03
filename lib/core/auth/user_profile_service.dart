import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Centralized service for provisioning and maintaining the user's primary
/// Firestore document (`users/{uid}`).
///
/// NOTE FOR MAINTAINERS:
/// Both Email/Password Signup and Google Sign-in/Sign-up must use this service
/// to create the `users/{uid}` document, ensuring schema consistency across
/// all registration entry points in Focusly.
class UserProfileService {
  final FirebaseFirestore _firestore;

  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Writes a new user profile document in Firestore at `users/{uid}`.
  Future<void> createUserDocument({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      debugPrint('[UserProfileService] Creating user document for UID: $uid');
      final document = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(document);
        transaction.set(document, {
          'uid': uid,
          'name': name.trim().isNotEmpty ? name.trim() : 'User',
          'email': email.trim(),
          if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
          'schemaVersion': 2,
        }, SetOptions(merge: true));
      });
      debugPrint('[UserProfileService] User document created successfully.');
    } catch (e, stack) {
      debugPrint(
        '[UserProfileService] Error creating user document: $e\n$stack',
      );
      rethrow;
    }
  }

  Future<void> recordTermsConsent(String uid) async {
    await _firestore.collection('users').doc(uid).set({
      'termsVersion': '2026-10-03',
      'termsAcceptedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Checks if a user document exists under `users/{uid}`. If it does not exist
  /// (such as when a new user signs up via Google for the first time), creates it.
  ///
  /// Returns `true` if a new profile document was created, or `false` if the
  /// user document already existed (returning user).
  Future<bool> ensureUserProfileDocument({
    required User user,
    String? fallbackName,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) return false;

        final name = (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (fallbackName?.trim().isNotEmpty == true
                  ? fallbackName!
                  : (user.email?.split('@').first ?? 'User'));
        transaction.set(docRef, {
          'uid': user.uid,
          'name': name.trim().isEmpty ? 'User' : name.trim(),
          'email': user.email?.trim() ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (e, stack) {
      debugPrint(
        '[UserProfileService] Error provisioning user profile: $e\n$stack',
      );
      // A failed read must never trigger a blind overwrite of an existing profile.
      rethrow;
    }
  }
}
