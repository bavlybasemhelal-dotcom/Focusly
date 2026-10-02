import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/group_member_model.dart';

/// Centralized service handling group lifecycle operations, including
/// complete cascade deletion, leaving groups, and managing membership requests.
///
/// NOTE FOR MAINTAINERS:
/// This service encapsulates the authoritative logic for deleting and leaving groups.
/// Both the Groups feature UI (Members Tab) and the global Account Deletion engine
/// MUST invoke these methods to avoid divergence in cascade-deletion behavior.
class GroupService {
  final FirebaseFirestore _firestore;

  GroupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Completely deletes a group and cascades deletion through all subcollections
  /// and member references across Firestore.
  ///
  /// ORDER OF OPERATIONS:
  /// 1. Query all group members (if not already provided in memory).
  /// 2. Remove [groupId] from every member's `users/{uid}.groupIds` array so the
  ///    group instantly disappears from their Active Groups dashboard.
  /// 3. Cascade-delete all nested subcollections under `groups/{groupId}`:
  ///    - `members` (all member and pending documents)
  ///    - `feed` (all group activity feed items)
  ///    - `challenges` (and each challenge's nested `participants` subcollection)
  ///    - `assignments` (and each assignment's nested `completions` subcollection)
  /// 4. Delete the root `groups/{groupId}` document itself.
  Future<void> deleteGroup(
    String groupId, {
    List<GroupMemberModel>? members,
  }) async {
    try {
      debugPrint('[GroupService] Initiating cascade deletion for group: $groupId');
      final groupRef = _firestore.collection('groups').doc(groupId);

      // 1. Gather all member UIDs to scrub groupIds from their user records
      List<String> memberUids = [];
      if (members != null && members.isNotEmpty) {
        memberUids = members.map((m) => m.uid).toList();
      } else {
        final membersSnap = await groupRef.collection('members').get();
        memberUids = membersSnap.docs.map((d) => d.id).toList();
      }

      // 2. Remove groupId from each user's groupIds array using batched writes
      if (memberUids.isNotEmpty) {
        final userBatch = _firestore.batch();
        for (final uid in memberUids) {
          final userRef = _firestore.collection('users').doc(uid);
          userBatch.set(
            userRef,
            {
              'groupIds': FieldValue.arrayRemove([groupId]),
            },
            SetOptions(merge: true),
          );
        }
        await userBatch.commit();
        debugPrint('[GroupService] Removed groupId from ${memberUids.length} members.');
      }

      // 3. Cascade delete `challenges` and their nested `participants`
      final challengesSnap = await groupRef.collection('challenges').get();
      for (final challengeDoc in challengesSnap.docs) {
        final participantsSnap =
            await challengeDoc.reference.collection('participants').get();
        if (participantsSnap.docs.isNotEmpty) {
          final pBatch = _firestore.batch();
          for (final pDoc in participantsSnap.docs) {
            pBatch.delete(pDoc.reference);
          }
          await pBatch.commit();
        }
        await challengeDoc.reference.delete();
      }

      // 4. Cascade delete `assignments` and their nested `completions`
      final assignmentsSnap = await groupRef.collection('assignments').get();
      for (final assignmentDoc in assignmentsSnap.docs) {
        final completionsSnap =
            await assignmentDoc.reference.collection('completions').get();
        if (completionsSnap.docs.isNotEmpty) {
          final cBatch = _firestore.batch();
          for (final cDoc in completionsSnap.docs) {
            cBatch.delete(cDoc.reference);
          }
          await cBatch.commit();
        }
        await assignmentDoc.reference.delete();
      }

      // 5. Cascade delete `feed` items
      final feedSnap = await groupRef.collection('feed').get();
      if (feedSnap.docs.isNotEmpty) {
        final feedBatch = _firestore.batch();
        for (final feedDoc in feedSnap.docs) {
          feedBatch.delete(feedDoc.reference);
        }
        await feedBatch.commit();
      }

      // 6. Cascade delete `members` documents
      final allMembersSnap = await groupRef.collection('members').get();
      if (allMembersSnap.docs.isNotEmpty) {
        final mBatch = _firestore.batch();
        for (final mDoc in allMembersSnap.docs) {
          mBatch.delete(mDoc.reference);
        }
        await mBatch.commit();
      }

      // 7. Finally delete the root group document
      await groupRef.delete();
      debugPrint('[GroupService] Successfully completed cascade deletion for group: $groupId');
    } catch (e, stack) {
      debugPrint('[GroupService] Error during deleteGroup cascade: $e\n$stack');
      rethrow;
    }
  }

  /// Removes a user from a group without destroying the group itself.
  ///
  /// OPERATION:
  /// - Deletes `groups/{groupId}/members/{uid}`.
  /// - Decrements `memberCount` on `groups/{groupId}`.
  /// - Removes `groupId` from `users/{uid}.groupIds`.
  /// - Runs inside a transaction to maintain consistency.
  Future<void> leaveGroup(String groupId, String uid) async {
    try {
      debugPrint('[GroupService] User $uid leaving group: $groupId');
      final groupRef = _firestore.collection('groups').doc(groupId);
      final memberRef = groupRef.collection('members').doc(uid);
      final userRef = _firestore.collection('users').doc(uid);

      await _firestore.runTransaction((transaction) async {
        final groupSnap = await transaction.get(groupRef);
        final currentCount =
            (groupSnap.data()?['memberCount'] as num?)?.toInt() ?? 1;

        transaction.delete(memberRef);
        if (groupSnap.exists) {
          transaction.update(
            groupRef,
            {'memberCount': (currentCount - 1).clamp(1, 999)},
          );
        }
        transaction.set(
          userRef,
          {
            'groupIds': FieldValue.arrayRemove([groupId]),
          },
          SetOptions(merge: true),
        );
      });
      debugPrint('[GroupService] User $uid left group: $groupId successfully');
    } catch (e, stack) {
      debugPrint('[GroupService] Error during leaveGroup: $e\n$stack');
      rethrow;
    }
  }

  /// Cancels or removes a pending membership join request for [uid] in [groupId].
  Future<void> cancelPendingRequest(String groupId, String uid) async {
    try {
      debugPrint('[GroupService] Cancelling pending request for user $uid in group $groupId');
      await _firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .doc(uid)
          .delete();
    } catch (e) {
      debugPrint('[GroupService] Error cancelling pending request: $e');
      rethrow;
    }
  }
}
