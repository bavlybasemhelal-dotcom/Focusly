import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/data/calendar_clock.dart';
import '../../../core/data/completion_ledger.dart';
import '../models/challenge_model.dart';
import '../models/challenge_participant_model.dart';
import '../models/group_feed_model.dart';
import '../models/group_member_model.dart';
import '../models/group_model.dart';

FirebaseFirestore? get _firestoreInstance {
  try {
    return FirebaseFirestore.instance;
  } catch (_) {
    return null;
  }
}

final groupsFirestoreProvider = Provider<FirebaseFirestore?>((ref) {
  return _firestoreInstance;
});

/// Stream of all Groups the current user belongs to (via users/{uid}.groupIds)
///
/// DATA ISOLATION & REAL-TIME SYNC:
/// 1. Watches [currentUserIdProvider] so user's group memberships are isolated per account.
/// 2. Rebuilds the group query when the membership list changes.
///    to ensure live real-time updates whenever group details (memberCount, name, icon, status)
///    change in Firestore without requiring a logout/login cycle or manual refresh.
final myGroupsStreamProvider = StreamProvider.autoDispose<List<GroupModel>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<GroupModel>[]);
  }

  final firestore = ref.watch(groupsFirestoreProvider);
  if (firestore == null) return Stream.value(<GroupModel>[]);

  final groupIdsState = ref.watch(_userGroupIdsProvider);
  if (groupIdsState.isLoading) return Stream.value(<GroupModel>[]);
  if (groupIdsState.hasError) {
    return Stream.error(groupIdsState.error!, groupIdsState.stackTrace);
  }
  final groupIds = groupIdsState.value ?? <String>[];
  if (groupIds.isEmpty) return Stream.value(<GroupModel>[]);

  // whereIn supports up to 10 IDs (Focusly caps max groups per user to 5)
  return firestore
      .collection('groups')
      .where(FieldPath.documentId, whereIn: groupIds)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList();
      });
});

final _userGroupIdsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  final firestore = ref.watch(groupsFirestoreProvider);
  if (uid == null || firestore == null) return Stream.value(<String>[]);
  return firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snapshot) => List<String>.from(snapshot.data()?['groupIds'] ?? []));
});

/// Stream of a specific Group document
final groupDetailStreamProvider = StreamProvider.autoDispose
    .family<GroupModel?, String>((ref, groupId) {
      if (ref.watch(currentUserIdProvider) == null) return Stream.value(null);
      final firestore = ref.watch(groupsFirestoreProvider);
      if (firestore == null) return Stream.value(null);

      return firestore
          .collection('groups')
          .doc(groupId)
          .snapshots()
          .map(
            (snap) => snap.exists && snap.data() != null
                ? GroupModel.fromMap(snap.data()!, snap.id)
                : null,
          );
    });

/// Stream of all members (approved & pending) in a Group
final groupMembersStreamProvider = StreamProvider.autoDispose
    .family<List<GroupMemberModel>, String>((ref, groupId) {
      if (ref.watch(currentUserIdProvider) == null) return Stream.value([]);
      final firestore = ref.watch(groupsFirestoreProvider);
      if (firestore == null) return Stream.value([]);

      return firestore
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => GroupMemberModel.fromMap(d.data(), d.id))
                .toList(),
          );
    });

/// Stream of feed items from the last 14 days, newest first
final groupFeedStreamProvider = StreamProvider.autoDispose
    .family<List<GroupFeedModel>, String>((ref, groupId) {
      if (ref.watch(currentUserIdProvider) == null) return Stream.value([]);
      final firestore = ref.watch(groupsFirestoreProvider);
      if (firestore == null) return Stream.value([]);

      final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

      return firestore
          .collection('groups')
          .doc(groupId)
          .collection('feed')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(fourteenDaysAgo),
          )
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => GroupFeedModel.fromMap(d.data(), d.id))
                .toList(),
          );
    });

/// Stream of all Challenges in a Group (active and recently finished)
final groupChallengesStreamProvider = StreamProvider.autoDispose
    .family<List<ChallengeModel>, String>((ref, groupId) {
      if (ref.watch(currentUserIdProvider) == null) return Stream.value([]);
      final firestore = ref.watch(groupsFirestoreProvider);
      if (firestore == null) return Stream.value([]);

      return firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .orderBy('endDate', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => ChallengeModel.fromMap(d.data(), d.id))
                .toList(),
          );
    });

/// Stream of participants inside a specific Challenge
final challengeParticipantsStreamProvider = StreamProvider.autoDispose
    .family<
      List<ChallengeParticipantModel>,
      ({String groupId, String challengeId})
    >((ref, arg) {
      if (ref.watch(currentUserIdProvider) == null) return Stream.value([]);
      final firestore = ref.watch(groupsFirestoreProvider);
      if (firestore == null) return Stream.value([]);

      return firestore
          .collection('groups')
          .doc(arg.groupId)
          .collection('challenges')
          .doc(arg.challengeId)
          .collection('participants')
          .orderBy('score', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs
                .map((d) => ChallengeParticipantModel.fromMap(d.data(), d.id))
                .toList(),
          );
    });

final weeklyGroupScoresProvider = StreamProvider.autoDispose
    .family<Map<String, int>, String>((ref, groupId) {
      final uid = ref.watch(currentUserIdProvider);
      final database = ref.watch(groupsFirestoreProvider);
      final week = CompletionLedger.weekKey(ref.watch(calendarClockProvider));
      if (uid == null || database == null) return Stream.value({});
      return database
          .collection('groups')
          .doc(groupId)
          .collection('weeklyScores')
          .where('week', isEqualTo: week)
          .snapshots()
          .map(
            (snapshot) => {
              for (final document in snapshot.docs)
                document.data()['uid'] as String: (document.data()['xp'] as num)
                    .toInt(),
            },
          );
    });

final groupLeaderboardProvider = Provider.autoDispose
    .family<List<GroupMemberModel>, String>((ref, groupId) {
      final members =
          ref.watch(groupMembersStreamProvider(groupId)).value ?? [];
      final scores = ref.watch(weeklyGroupScoresProvider(groupId)).value ?? {};
      final approved = members
          .where((member) => member.isApproved)
          .map((member) => member.copyWith(weeklyXP: scores[member.uid] ?? 0))
          .toList();
      approved.sort((left, right) {
        final byScore = right.weeklyXP.compareTo(left.weeklyXP);
        return byScore != 0 ? byScore : left.uid.compareTo(right.uid);
      });
      return approved;
    });

/// Aggregated stats strip data for Feed tab header
class GroupStatsSummary {
  final int totalWeeklyXP;
  final int activeMembersCount;
  final int recentActivityCount;

  const GroupStatsSummary({
    this.totalWeeklyXP = 0,
    this.activeMembersCount = 0,
    this.recentActivityCount = 0,
  });
}

/// Provider computing group weekly summary stats
final groupStatsSummaryProvider = Provider.autoDispose
    .family<GroupStatsSummary, String>((ref, groupId) {
      final members = ref.watch(groupLeaderboardProvider(groupId));
      final feedItems = ref.watch(groupFeedStreamProvider(groupId)).value ?? [];

      final approved = members.where((m) => m.isApproved).toList();
      final totalXp = approved.fold<int>(0, (total, m) => total + m.weeklyXP);
      final activeMembers = approved.where((m) => m.weeklyXP > 0).length;

      return GroupStatsSummary(
        totalWeeklyXP: totalXp,
        activeMembersCount: activeMembers,
        recentActivityCount: feedItems.length,
      );
    });
