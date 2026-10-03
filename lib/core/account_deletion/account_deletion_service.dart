import 'deletion_checkpoint.dart';
import '../data/pending_operations.dart';
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
  String? _deletionUid;

  AccountDeletionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GroupService? groupService,
  }) : _auth = auth ?? FirebaseAuth.instance,
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
    if (_deletionUid != null && _deletionUid != uid) {
      throw StateError(
        'The signed-in account changed during deletion. Sign in to the original account and retry.',
      );
    }
    _deletionUid = uid;
    // Prompt before deleting data: cancelling reauthentication must keep the account intact.
    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null ||
        DateTime.now().difference(lastSignIn) > const Duration(minutes: 5)) {
      throw ReauthenticationRequiredException(
        providerIds: user.providerData.map((info) => info.providerId).toList(),
        email: user.email,
      );
    }
    await DeletionCheckpoint.set(uid, true);
    // A minimal UID-only deletion barrier survives root removal and prevents
    // profile recreation from a second device if Auth deletion needs a retry.
    await _firestore.collection('accountDeletions').doc(uid).set({
      'pending': true,
    }, SetOptions(merge: true));
    await _firestore.collection('users').doc(uid).set({
      'deletionPending': true,
      'deletionStartedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint(
      '[AccountDeletion] >>> Starting complete account deletion for UID: $uid <<<',
    );

    // -------------------------------------------------------------------------
    // PHASE 1: GROUP CLEANUP & CASCADE
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Cleaning up group memberships and created groups...');
      debugPrint(
        '[AccountDeletion] [Phase 1/4] Processing group memberships and cascade deletion...',
      );
      await _handleGroupDeletion(uid);
      await _eraseFormerSharedRecords(uid);
      await _firestore.collection('users').doc(uid).set({
        'deletionPhase': 'personalData',
      }, SetOptions(merge: true));
      debugPrint(
        '[AccountDeletion] [Phase 1/4] Groups processed successfully.',
      );
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
      debugPrint(
        '[AccountDeletion] [Phase 2/4] Deleting all 43 per-user Firestore subcollections...',
      );
      await _deleteUserSubcollections(uid, onProgress: onProgress);
      await _firestore.collection('users').doc(uid).set({
        'deletionPhase': 'authentication',
      }, SetOptions(merge: true));
      debugPrint(
        '[AccountDeletion] [Phase 2/4] All subcollections cleared successfully.',
      );
    } catch (e, stack) {
      debugPrint(
        '[AccountDeletion] ERROR in Phase 2 (Subcollections): $e\n$stack',
      );
      rethrow;
    }

    // -------------------------------------------------------------------------
    // PHASE 3: ROOT USER DOCUMENT
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Removing user profile...');
      debugPrint(
        '[AccountDeletion] [Phase 3/4] Deleting root users/$uid document...',
      );
      await _firestore.collection('users').doc(uid).delete();
      debugPrint('[AccountDeletion] [Phase 3/4] Root user document deleted.');
    } catch (e, stack) {
      debugPrint(
        '[AccountDeletion] ERROR in Phase 3 (Root user doc): $e\n$stack',
      );
      rethrow;
    }

    // -------------------------------------------------------------------------
    // PHASE 4: FIREBASE AUTH ACCOUNT DELETION
    // -------------------------------------------------------------------------
    try {
      onProgress?.call('Finalizing account removal with Firebase Auth...');
      debugPrint(
        '[AccountDeletion] [Phase 4/4] Deleting Firebase Auth user...',
      );
      await user.delete().timeout(const Duration(seconds: 15));
      await PendingOperations.clearAccount(uid);
      debugPrint(
        '[AccountDeletion] [Phase 4/4] Firebase Auth user deleted successfully!',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        debugPrint(
          '[AccountDeletion] Auth requires recent login for UID: $uid',
        );
        final providerIds = user.providerData
            .map((info) => info.providerId)
            .toList();
        throw ReauthenticationRequiredException(
          providerIds: providerIds,
          email: user.email,
        );
      }
      debugPrint(
        '[AccountDeletion] ERROR in Phase 4 (FirebaseAuthException): [${e.code}] ${e.message}',
      );
      rethrow;
    } catch (e, stack) {
      debugPrint(
        '[AccountDeletion] ERROR in Phase 4 (Auth user deletion): $e\n$stack',
      );
      rethrow;
    }

    await DeletionCheckpoint.set(uid, false);
    debugPrint(
      '[AccountDeletion] >>> Complete account deletion finished successfully for UID: $uid <<<',
    );
  }

  /// Retries the complete deletion after a successful reauthentication.
  Future<void> finalizeAuthDeletionAfterReauth() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
        'No active user session to delete after re-authentication.',
      );
    }
    debugPrint(
      '[AccountDeletion] Retrying complete cleanup post re-authentication...',
    );
    await deleteCurrentAccount();
    debugPrint(
      '[AccountDeletion] User account successfully deleted post re-authentication.',
    );
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
      debugPrint('[AccountDeletion] Could not discover all memberships: $e');
      rethrow;
    }

    debugPrint(
      '[AccountDeletion] Inspecting ${allGroupIdsToInspect.length} groups for user $uid',
    );

    for (final groupId in allGroupIdsToInspect) {
      if (processedGroupIds.contains(groupId)) continue;
      processedGroupIds.add(groupId);

      try {
        final groupDoc = await _firestore
            .collection('groups')
            .doc(groupId)
            .get();
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

        String status = 'approved';

        if (memberDoc.exists) {
          final member = GroupMemberModel.fromMap(memberDoc.data()!, uid);
          status = member.status;
        }

        final bool isAdmin = createdBy == uid;

        if (isAdmin) {
          // ADMIN: Cascade delete the ENTIRE group (removing it for all members)
          debugPrint(
            '[AccountDeletion] User is ADMIN of group $groupId. Triggering full cascade deletion.',
          );
          await _groupService.deleteGroup(groupId);
        } else if (status == 'pending') {
          // PENDING: Remove the pending application doc
          debugPrint(
            '[AccountDeletion] User has PENDING request in group $groupId. Cancelling request.',
          );
          await _groupService.cancelPendingRequest(groupId, uid);
        } else {
          // MEMBER: Leave group normally (removes member doc and decrements memberCount)
          debugPrint(
            '[AccountDeletion] User is MEMBER of group $groupId. Leaving group.',
          );
          await _groupService.eraseMemberActivity(groupId, uid);
          await _groupService.leaveGroup(groupId, uid);
        }
      } catch (e) {
        debugPrint('[AccountDeletion] Error processing group $groupId: $e');
        rethrow;
      }
    }
  }

  /// Finds own records even after an old membership document was removed.
  Future<void> _eraseFormerSharedRecords(String uid) async {
    // These indexed queries also find activity left behind by an old membership.
    for (final field in ['createdBy', 'approvedBy', 'winnerUids']) {
      while (true) {
        final query = field == 'winnerUids'
            ? _firestore
                  .collectionGroup('challenges')
                  .where(field, arrayContains: uid)
            : _firestore
                  .collectionGroup('challenges')
                  .where(field, isEqualTo: uid);
        final page = await query.limit(100).get();
        if (page.docs.isEmpty) break;
        for (final doc in page.docs) {
          final patch = field == 'winnerUids'
              ? <String, dynamic>{
                  'winnerUids': FieldValue.arrayRemove([uid]),
                  'winnerUid': null,
                  'winnerName': null,
                }
              : <String, dynamic>{field: null};
          await doc.reference.update(patch);
        }
      }
    }
    while (true) {
      final page = await _firestore
          .collectionGroup('audit')
          .where('actorUid', isEqualTo: uid)
          .limit(100)
          .get();
      if (page.docs.isEmpty) break;
      for (final doc in page.docs) {
        await doc.reference.delete();
      }
    }
    while (true) {
      final page = await _firestore
          .collectionGroup('feed')
          .where('reactionUids', arrayContains: uid)
          .limit(100)
          .get();
      if (page.docs.isEmpty) break;
      for (final doc in page.docs) {
        await _firestore.runTransaction((transaction) async {
          final fresh = await transaction.get(doc.reference);
          if (!fresh.exists) return;
          final reactions = Map<String, dynamic>.from(
            fresh.data()?['reactions'] as Map? ?? {},
          );
          final reactedBy = Map<String, dynamic>.from(
            fresh.data()?['reactedBy'] as Map? ?? {},
          );
          final previous = reactedBy.remove(uid);
          if (previous != null) {
            reactions[previous] =
                ((reactions[previous] as num?)?.toInt() ?? 1) - 1;
          }
          transaction.update(doc.reference, {
            'reactions': reactions,
            'reactedBy': reactedBy,
            'reactionUids': reactedBy.keys.toList(),
          });
        });
      }
    }
    for (final name in [
      'feed',
      'xpEvents',
      'weeklyScores',
      'scoreEvents',
      'completions',
      'participants',
    ]) {
      while (true) {
        final page = await _firestore
            .collectionGroup(name)
            .where('uid', isEqualTo: uid)
            .limit(100)
            .get();
        final shared = page.docs
            .where((doc) => doc.reference.path.startsWith('groups/'))
            .toList();
        if (shared.isEmpty) break;
        for (final doc in shared) {
          if (name == 'participants') {
            await _groupService.removeChallengeParticipant(
              doc.reference.parent.parent!,
              uid,
            );
          } else {
            await doc.reference.delete();
          }
        }
      }
    }
  }

  /// Iterates through every collection in [kUserDataSubcollections] and deletes
  /// all documents under `users/{uid}/{subcollection}` using batched writes.
  Future<void> _deleteUserSubcollections(
    String uid, {
    void Function(String stepDescription)? onProgress,
  }) async {
    const int batchLimit =
        400; // Comfortable margin below Firestore's 500 limit
    final userRef = _firestore.collection('users').doc(uid);
    await userRef.collection('stats').doc('progress').delete();

    int deletedCollectionsCount = 0;

    for (final collectionName in kUserDataSubcollections) {
      try {
        final subcollectionRef = userRef.collection(collectionName);
        while (true) {
          final snapshot = await subcollectionRef.limit(batchLimit).get();
          if (snapshot.docs.isEmpty) break;
          final batch = _firestore.batch();
          for (final doc in snapshot.docs) {
            if (collectionName == 'skills') {
              for (final name in ['taskClaims', 'dailyProgress']) {
                while (true) {
                  final children = await doc.reference
                      .collection(name)
                      .limit(200)
                      .get();
                  if (children.docs.isEmpty) break;
                  final childBatch = _firestore.batch();
                  for (final child in children.docs) {
                    childBatch.delete(child.reference);
                  }
                  await childBatch.commit();
                }
              }
            }
            batch.delete(doc.reference);
          }

          await batch.commit();
        }

        deletedCollectionsCount++;
      } catch (e) {
        debugPrint(
          '[AccountDeletion] Error clearing subcollection $collectionName: $e',
        );
        rethrow;
      }
    }

    debugPrint(
      '[AccountDeletion] Cleared $deletedCollectionsCount registered subcollections.',
    );
  }
}
