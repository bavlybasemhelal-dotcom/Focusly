import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../features/groups/models/group_member_model.dart';
import '../../features/groups/services/group_service.dart';
import 'user_data_collections.dart';

/// Exception thrown when the Firebase Auth account deletion fails because
/// a sensitive operation requires recent credentials (`requires-recent-login`).
class ReauthenticationRequiredException implements Exception {
  final List<String> providerIds;
  final String? email;

  const ReauthenticationRequiredException({
    required this.providerIds,
    this.email,
  });

  bool get hasPasswordProvider => providerIds.contains('password');
  bool get hasGoogleProvider => providerIds.contains('google.com');

  @override
  String toString() =>
      'ReauthenticationRequiredException: recent sign-in required for providers: $providerIds';
}

/// Service executing permanent, complete deletion of a user's account and all
/// associated data across Focusly and Firebase.
///
/// ==============================================================================
/// STRICT ORDER OF OPERATIONS:
/// ==============================================================================
/// 1. GROUPS PHASE (MUST RUN FIRST):
///    Affects other users' data and dashboards.
///    - Admin groups (created by user): cascade-delete entire group & all subcollections.
///    - Member groups: remove only user's membership & decrement memberCount.
///    - Pending requests: delete pending join request doc.
///
/// 2. USER DATA PHASE:
///    Iterate through all 43 registered subcollections in [kUserDataSubcollections]
///    under `users/{uid}/...` and delete every document using Firestore batched writes.
///
/// 3. ROOT USER DOCUMENT PHASE:
///    Delete the top-level `users/{uid}` document.
///
/// 4. AUTHENTICATION ACCOUNT PHASE:
///    Delete the user's Firebase Auth account (`user.delete()`).
///    If `requires-recent-login` is thrown, prompts re-authentication and retries.
/// ==============================================================================
class AccountDeletionService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GroupService _groupService;

  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GroupService? groupService,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _groupService = groupService ?? GroupService(firestore: firestore);

  /// Executes the complete account deletion process for the current authenticated user.
  ///
  /// Throws [ReauthenticationRequiredException] if Firebase Auth requires a fresh login.
  /// Throws [Exception] if any phase encounters an unrecoverable failure.
  Future<void> deleteCurrentAccount({
    void Function(String stepDescription)? onProgress,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user session found to delete.');
    }

    final uid = user.uid;
    debugPrint('[AccountDeletion] >>> Starting complete account deletion for UID: $uid <<<');

    // -------------------------------------------------------------------------
    // PHASE 1: GROUP CLEANUP & CASCADE
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Cleaning up group memberships and created groups...');
      debugPrint('[AccountDeletion] [Phase 1/4] Processing group memberships and cascade deletion...');
      await _handleGroupDeletion(uid);
      debugPrint('[AccountDeletion] [Phase 1/4] Groups processed successfully.');
    } catch (e, stack) {
      debugPrint('[AccountDeletion] ERROR in Phase 1 (Groups): $e\n$stack');
      // Log failure point for team diagnosis
      rethrow;
    }

    // -------------------------------------------------------------------------
    // PHASE 2: PER-USER SUBCOLLECTIONS (ALL 43 COLLECTIONS)
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Erasing personal data and activity records...');
      debugPrint('[AccountDeletion] [Phase 2/4] Deleting all 43 per-user Firestore subcollections...');
      await _deleteUserSubcollections(uid, onProgress: onProgress);
      debugPrint('[AccountDeletion] [Phase 2/4] All subcollections cleared successfully.');
    } catch (e, stack) {
      debugPrint('[AccountDeletion] ERROR in Phase 2 (Subcollections): $e\n$stack');
      // TODO: In a future release, implement an idempotent "resume partial deletion"
      // mechanism (e.g. saving an in-progress deletion marker document under users/{uid}/_deletionState)
      // to cleanly resume if interrupted mid-stream. The ordered batched architecture
      // used here minimizes inconsistent states in the meantime.
      rethrow;
    }

    // -------------------------------------------------------------------------
    // PHASE 3: ROOT USER DOCUMENT
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Removing user profile...');
      debugPrint('[AccountDeletion] [Phase 3/4] Deleting root users/$uid document...');
      await _firestore.collection('users').doc(uid).delete();
      debugPrint('[AccountDeletion] [Phase 3/4] Root user document deleted.');
    } catch (e, stack) {
      debugPrint('[AccountDeletion] ERROR in Phase 3 (Root user doc): $e\n$stack');
      rethrow;
    }

    // -------------------------------------------------------------------------
    // PHASE 4: FIREBASE AUTH ACCOUNT DELETION
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Finalizing account removal with Firebase Auth...');
      debugPrint('[AccountDeletion] [Phase 4/4] Deleting Firebase Auth user...');
      await user.delete().timeout(const Duration(seconds: 15));
      debugPrint('[AccountDeletion] [Phase 4/4] Firebase Auth user deleted successfully!');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint('[AccountDeletion] Auth requires recent login for UID: $uid');
        final providerIds =
            user.providerData.map((info) => info.providerId).toList();
        throw ReauthenticationRequiredException(
          providerIds: providerIds,
          email: user.email,
        );
      }
      debugPrint('[AccountDeletion] ERROR in Phase 4 (FirebaseAuthException): [${e.code}] ${e.message}');
      rethrow;
    } catch (e, stack) {
      debugPrint('[AccountDeletion] ERROR in Phase 4 (Auth user deletion): $e\n$stack');
      rethrow;
    }

    debugPrint('[AccountDeletion] >>> Complete account deletion finished successfully for UID: $uid <<<');
  }

  /// Retries deleting ONLY the Firebase Auth user after a successful re-authentication.
  /// (Used when all Firestore data has already been cleared in Phases 1-3).
  Future<void> finalizeAuthDeletionAfterReauth() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No active user session to delete after re-authentication.');
    }
    debugPrint('[AccountDeletion] Retrying user.delete() post re-authentication...');
    await user.delete().timeout(const Duration(seconds: 15));
    debugPrint('[AccountDeletion] User account successfully deleted post re-authentication.');
  }

  /// Queries all groups the user participates in or has requested to join,
  /// routing each to either [GroupService.deleteGroup], [GroupService.leaveGroup],
  /// or [GroupService.cancelPendingRequest].
  Future<void> _handleGroupDeletion(String uid) async {
    final Set<String> processedGroupIds = {};

    // 1. Fetch user's active groupIds from their user document
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final List<String> activeGroupIds = List<String>.from(
      userDoc.data()?['groupIds'] ?? [],
    );

    // 2. Also query collectionGroup('members') where uid == uid
    // This catches pending requests AND any groups where user is a member
    final Set<String> allGroupIdsToInspect = Set.from(activeGroupIds);
    try {
      final memberDocsSnap = await _firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .get();

      for (final doc in memberDocsSnap.docs) {
        // Parent path of doc is: groups/{groupId}/members/{uid}
        final groupDocRef = doc.reference.parent.parent;
        if (groupDocRef != null && groupDocRef.id.isNotEmpty) {
          allGroupIdsToInspect.add(groupDocRef.id);
        }
      }
    } catch (e) {
      debugPrint('[AccountDeletion] collectionGroup query fallback (using activeGroupIds): $e');
    }

    debugPrint('[AccountDeletion] Inspecting ${allGroupIdsToInspect.length} groups for user $uid');

    for (final groupId in allGroupIdsToInspect) {
      if (processedGroupIds.contains(groupId)) continue;
      processedGroupIds.add(groupId);

      try {
        final groupDoc =
            await _firestore.collection('groups').doc(groupId).get();
        if (!groupDoc.exists) continue;

        final groupData = groupDoc.data() ?? {};
        final createdBy = groupData['createdBy'] as String? ?? '';

        // Check member record to determine role and status
        final memberDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(uid)
            .get();

        String role = 'member';
        String status = 'approved';

        if (memberDoc.exists) {
          final member = GroupMemberModel.fromMap(memberDoc.data()!, uid);
          role = member.role;
          status = member.status;
        }

        final bool isAdmin = (createdBy == uid) || (role == 'admin');

        if (isAdmin) {
          // ADMIN: Cascade delete the ENTIRE group (removing it for all members)
          debugPrint('[AccountDeletion] User is ADMIN of group $groupId. Triggering full cascade deletion.');
          await _groupService.deleteGroup(groupId);
        } else if (status == 'pending') {
          // PENDING: Remove the pending application doc
          debugPrint('[AccountDeletion] User has PENDING request in group $groupId. Cancelling request.');
          await _groupService.cancelPendingRequest(groupId, uid);
        } else {
          // MEMBER: Leave group normally (removes member doc and decrements memberCount)
          debugPrint('[AccountDeletion] User is MEMBER of group $groupId. Leaving group.');
          await _groupService.leaveGroup(groupId, uid);
        }
      } catch (e) {
        debugPrint('[AccountDeletion] Error processing group $groupId: $e');
        // Continue to next group to ensure maximum data is cleared
      }
    }
  }

  /// Iterates through every collection in [kUserDataSubcollections] and deletes
  /// all documents under `users/{uid}/{subcollection}` using batched writes.
  Future<void> _deleteUserSubcollections(
    String uid, {
    void Function(String stepDescription)? onProgress,
  }) async {
    const int batchLimit = 400; // Comfortable margin below Firestore's 500 limit
    final userRef = _firestore.collection('users').doc(uid);

    int deletedCollectionsCount = 0;

    for (final collectionName in kUserDataSubcollections) {
      try {
        final subcollectionRef = userRef.collection(collectionName);
        final snapshot = await subcollectionRef.get();

        if (snapshot.docs.isEmpty) continue;

        final docs = snapshot.docs;
        debugPrint('[AccountDeletion] Deleting ${docs.length} documents from $collectionName...');

        for (var i = 0; i < docs.length; i += batchLimit) {
          final batch = _firestore.batch();
          final end = (i + batchLimit < docs.length) ? i + batchLimit : docs.length;
          final chunk = docs.sublist(i, end);

          for (final doc in chunk) {
            batch.delete(doc.reference);
          }

          await batch.commit();
        }

        deletedCollectionsCount++;
      } catch (e) {
        debugPrint('[AccountDeletion] Error clearing subcollection $collectionName: $e');
        // Continue with remaining collections to ensure maximal deletion
      }
    }

    debugPrint('[AccountDeletion] Processed all ${kUserDataSubcollections.length} subcollections (cleared $deletedCollectionsCount active ones).');
  }
}
