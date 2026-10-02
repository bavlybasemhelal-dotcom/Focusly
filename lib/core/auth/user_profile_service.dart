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
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name.trim().isNotEmpty ? name.trim() : 'User',
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[UserProfileService] User document created successfully.');
    } catch (e, stack) {
      debugPrint('[UserProfileService] Error creating user document: $e\n$stack');
      rethrow;
    }
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
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        debugPrint('[UserProfileService] New user detected (${user.uid}). Provisioning profile document...');
        final name = (user.displayName?.trim().isNotEmpty == true)
            ? user.displayName!
            : (fallbackName?.trim().isNotEmpty == true
                ? fallbackName!
                : (user.email?.split('@').first ?? 'User'));

        await createUserDocument(
          uid: user.uid,
          name: name,
          email: user.email ?? '',
        );
        return true;
      } else {
        debugPrint('[UserProfileService] Returning user document found for UID: ${user.uid}');
        return false;
      }
    } catch (e, stack) {
      debugPrint('[UserProfileService] Error checking/creating user profile: $e\n$stack');
      // If reading fails, attempt to create without overwriting blindly
      try {
        await createUserDocument(
          uid: user.uid,
          name: user.displayName ?? (fallbackName ?? 'User'),
          email: user.email ?? '',
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }
}
