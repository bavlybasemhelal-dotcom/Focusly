import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final String? Function() _actorProvider;

  GroupService({
    FirebaseFirestore? firestore,
    String? Function()? actorProvider,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _actorProvider =
           actorProvider ?? (() => FirebaseAuth.instance.currentUser?.uid);

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
      debugPrint(
        '[GroupService] Initiating cascade deletion for group: $groupId',
      );
      final groupRef = _firestore.collection('groups').doc(groupId);

      // 1. Gather all member UIDs to scrub groupIds from their user records
      List<String> memberUids = [];
      final membersSnap = await groupRef.collection('members').get();
      memberUids = membersSnap.docs
          .where((doc) => doc.data()['status'] == 'approved')
          .map((doc) => doc.id)
          .toList();

      final groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists) return;
      await groupRef.update({'deletionPending': true});
      for (final uid in memberUids) {
        await detachAssignments(groupId, uid);
      }

      // 2. Remove groupId from each user's groupIds array using batched writes
      if (memberUids.isNotEmpty) {
        final userBatch = _firestore.batch();
        for (final uid in memberUids) {
          final userRef = _firestore.collection('users').doc(uid);
          userBatch.set(userRef, {
            'groupIds': FieldValue.arrayRemove([groupId]),
          }, SetOptions(merge: true));
        }
        await userBatch.commit();
        debugPrint(
          '[GroupService] Removed groupId from ${memberUids.length} members.',
        );
      }

      // 3. Cascade delete `challenges` and their nested `participants`
      final challengesSnap = await groupRef.collection('challenges').get();
      for (final challengeDoc in challengesSnap.docs) {
        await _deleteCollection(
          challengeDoc.reference.collection('participants'),
        );
        await _deleteCollection(
          challengeDoc.reference.collection('scoreEvents'),
        );
        await challengeDoc.reference.delete();
      }

      // 4. Cascade delete `assignments` and their nested `completions`
      final assignmentsSnap = await groupRef.collection('assignments').get();
      for (final assignmentDoc in assignmentsSnap.docs) {
        await _deleteCollection(
          assignmentDoc.reference.collection('completions'),
        );
        await assignmentDoc.reference.delete();
      }

      // 5. Cascade delete `feed` items
      await _deleteCollection(groupRef.collection('feed'));
      await _deleteCollection(groupRef.collection('xpEvents'));
      await _deleteCollection(groupRef.collection('weeklyScores'));
      await _deleteCollection(groupRef.collection('audit'));
      final invite = groupSnapshot.data()?['inviteCode'];
      if (invite is String && invite.isNotEmpty) {
        await _firestore.collection('invites').doc(invite).delete();
      }

      // 6. Cascade delete `members` documents
      await _deleteCollection(groupRef.collection('members'));

      // 7. Finally delete the root group document
      await groupRef.delete();
      debugPrint(
        '[GroupService] Successfully completed cascade deletion for group: $groupId',
      );
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
        final memberSnap = await transaction.get(memberRef);
        final currentCount =
            (groupSnap.data()?['memberCount'] as num?)?.toInt() ?? 1;

        if (groupSnap.exists && memberSnap.data()?['status'] == 'approved') {
          transaction.update(memberRef, {'status': 'leaving'});
          transaction.update(groupRef, {
            'memberCount': (currentCount - 1).clamp(0, 999),
            'lastMembershipUid': uid,
          });
        }
        transaction.set(userRef, {
          'groupIds': FieldValue.arrayRemove([groupId]),
        }, SetOptions(merge: true));
      });
      await detachAssignments(groupId, uid);
      await memberRef.delete();
      debugPrint('[GroupService] User $uid left group: $groupId successfully');
    } catch (e, stack) {
      debugPrint('[GroupService] Error during leaveGroup: $e\n$stack');
      rethrow;
    }
  }

  /// Keeps the member's own work while removing obsolete assignment locks.
  Future<void> detachAssignments(String groupId, String uid) async {
    for (final collection in ['tasks', 'habits']) {
      while (true) {
        final items = await _firestore
            .collection('users')
            .doc(uid)
            .collection(collection)
            .where('assignedByGroupId', isEqualTo: groupId)
            .limit(100)
            .get();
        if (items.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final item in items.docs) {
          batch.update(item.reference, {
            'locked': false,
            'assignedByGroupId': null,
            'groupAssignmentId': null,
            'assignedByName': null,
          });
        }
        await batch.commit();
      }
    }
  }

  /// Removes identifying shared records before an account loses membership.
  Future<void> eraseMemberActivity(String groupId, String uid) async {
    final group = _firestore.collection('groups').doc(groupId);
    while (true) {
      final feed = await group
          .collection('feed')
          .where('uid', isEqualTo: uid)
          .limit(100)
          .get();
      if (feed.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final entry in feed.docs) {
        batch.delete(entry.reference);
      }
      await batch.commit();
    }
    final challenges = await group.collection('challenges').get();
    for (final challenge in challenges.docs) {
      await _deleteOwnedQuery(
        challenge.reference
            .collection('scoreEvents')
            .where('uid', isEqualTo: uid),
      );
      await removeChallengeParticipant(challenge.reference, uid);
    }
    await _deleteOwnedQuery(
      group.collection('xpEvents').where('uid', isEqualTo: uid),
    );
    await _deleteOwnedQuery(
      group.collection('weeklyScores').where('uid', isEqualTo: uid),
    );
    final assignments = await group.collection('assignments').get();
    for (final assignment in assignments.docs) {
      await assignment.reference.collection('completions').doc(uid).delete();
    }
  }

  Future<void> _deleteOwnedQuery(Query<Map<String, dynamic>> query) async {
    while (true) {
      final page = await query.limit(100).get();
      if (page.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> removeChallengeParticipant(
    DocumentReference<Map<String, dynamic>> challenge,
    String uid,
  ) async {
    await _firestore.runTransaction((transaction) async {
      final parent = await transaction.get(challenge);
      final participant = await transaction.get(
        challenge.collection('participants').doc(uid),
      );
      if (!participant.exists) return;
      if (parent.exists) {
        final data = parent.data()!;
        final winners =
            (data['winnerUids'] as List?)?.whereType<String>().toList() ??
            <String>[];
        final patch = <String, dynamic>{
          'participantCount':
              ((data['participantCount'] as num?)?.toInt() ?? 1) - 1,
          'lastRemovedParticipant': uid,
        };
        if (data['winnerUid'] == uid || winners.contains(uid)) {
          patch.addAll({
            'winnerUid': null,
            'winnerName': null,
            'winnerUids': winners.where((value) => value != uid).toList(),
          });
        }
        transaction.update(challenge, patch);
      }
      transaction.delete(participant.reference);
    });
  }

  /// Deletes a collection in bounded batches, including feeds with over 500 items.
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final page = await collection.limit(400).get();
      if (page.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Approval is idempotent and checks capacity inside the transaction.
  Future<void> approveMember(String groupId, String uid) async {
    final actor = _actorProvider();
    final groupRef = _firestore.collection('groups').doc(groupId);
    final memberRef = groupRef.collection('members').doc(uid);
    await _firestore.runTransaction((transaction) async {
      final group = await transaction.get(groupRef);
      final member = await transaction.get(memberRef);
      if (!group.exists || !member.exists) {
        throw StateError('Group or request no longer exists');
      }
      if (member.data()?['status'] == 'approved') return;
      final count = (group.data()?['memberCount'] as num?)?.toInt() ?? 1;
      final maxMembers = (group.data()?['maxMembers'] as num?)?.toInt() ?? 20;
      if (count >= maxMembers) throw StateError('Group is full');
      transaction.update(memberRef, {
        'status': 'approved',
        'joinedAt': Timestamp.now(),
      });
      transaction.update(groupRef, {'memberCount': count + 1});
      transaction.update(groupRef, {'lastMembershipUid': uid});
      if (actor != null) {
        transaction.set(groupRef.collection('audit').doc(), {
          'actorUid': actor,
          'action': 'approveMember',
          'target': uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(_firestore.collection('users').doc(uid), {
        'groupIds': FieldValue.arrayUnion([groupId]),
      }, SetOptions(merge: true));
    });
  }

  /// Cancels or removes a pending membership join request for [uid] in [groupId].
  Future<void> cancelPendingRequest(String groupId, String uid) async {
    try {
      debugPrint(
        '[GroupService] Cancelling pending request for user $uid in group $groupId',
      );
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
