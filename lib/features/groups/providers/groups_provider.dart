import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Stream of all Groups the current user belongs to (via users/{uid}.groupIds)
final myGroupsStreamProvider =
    StreamProvider.autoDispose<List<GroupModel>>((ref) {
  String? uid;
  try {
    uid = FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {}

  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }

  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value([]);

  return firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .asyncMap((userSnap) async {
    if (!userSnap.exists) return <GroupModel>[];
    final groupIds = List<String>.from(userSnap.data()?['groupIds'] ?? []);
    if (groupIds.isEmpty) return <GroupModel>[];

    final groups = <GroupModel>[];
    for (final id in groupIds) {
      try {
        final gDoc = await firestore.collection('groups').doc(id).get();
        if (gDoc.exists && gDoc.data() != null) {
          groups.add(GroupModel.fromMap(gDoc.data()!, gDoc.id));
        }
      } catch (_) {}
    }
    return groups;
  });
});

/// Stream of a specific Group document
final groupDetailStreamProvider =
    StreamProvider.autoDispose.family<GroupModel?, String>((ref, groupId) {
  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value(null);

  return firestore
      .collection('groups')
      .doc(groupId)
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? GroupModel.fromMap(snap.data()!, snap.id)
          : null);
});

/// Stream of all members (approved & pending) in a Group
final groupMembersStreamProvider =
    StreamProvider.autoDispose.family<List<GroupMemberModel>, String>((ref, groupId) {
  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value([]);

  return firestore
      .collection('groups')
      .doc(groupId)
      .collection('members')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => GroupMemberModel.fromMap(d.data(), d.id))
          .toList());
});

/// Stream of feed items from the last 14 days, newest first
final groupFeedStreamProvider =
    StreamProvider.autoDispose.family<List<GroupFeedModel>, String>((ref, groupId) {
  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value([]);

  final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));

  return firestore
      .collection('groups')
      .doc(groupId)
      .collection('feed')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(fourteenDaysAgo))
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => GroupFeedModel.fromMap(d.data(), d.id))
          .toList());
});

/// Stream of all Challenges in a Group (active and recently finished)
final groupChallengesStreamProvider =
    StreamProvider.autoDispose.family<List<ChallengeModel>, String>((ref, groupId) {
  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value([]);

  return firestore
      .collection('groups')
      .doc(groupId)
      .collection('challenges')
      .orderBy('endDate', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ChallengeModel.fromMap(d.data(), d.id))
          .toList());
});

/// Stream of participants inside a specific Challenge
final challengeParticipantsStreamProvider = StreamProvider.autoDispose
    .family<List<ChallengeParticipantModel>, ({String groupId, String challengeId})>(
        (ref, arg) {
  final firestore = _firestoreInstance;
  if (firestore == null) return Stream.value([]);

  return firestore
      .collection('groups')
      .doc(arg.groupId)
      .collection('challenges')
      .doc(arg.challengeId)
      .collection('participants')
      .orderBy('score', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ChallengeParticipantModel.fromMap(d.data(), d.id))
          .toList());
});

/// Leaderboard provider: computes approved members sorted by weeklyXP descending,
/// and executes weekly reset if the group's weekStart is stale.
final groupLeaderboardProvider =
    Provider.autoDispose.family<List<GroupMemberModel>, String>((ref, groupId) {
  final membersAsync = ref.watch(groupMembersStreamProvider(groupId));
  final groupAsync = ref.watch(groupDetailStreamProvider(groupId));

  final members = membersAsync.value ?? [];
  final group = groupAsync.value;

  // Filter approved members only
  final approvedMembers =
      members.where((m) => m.isApproved).toList();

  // Sort by weeklyXP descending
  approvedMembers.sort((a, b) => b.weeklyXP.compareTo(a.weeklyXP));

  // Client-side weekly XP reset check
  if (group != null) {
    _checkAndResetWeeklyXp(group, members);
  }

  return approvedMembers;
});

/// Helper to trigger client-side weekly reset if weekStart is from a previous calendar week
Future<void> _checkAndResetWeeklyXp(
  GroupModel group,
  List<GroupMemberModel> members,
) async {
  final now = DateTime.now();
  final currentWeekStart = DateTime(now.year, now.month, now.day - (now.weekday % 7));

  if (group.weekStart == null || group.weekStart!.isBefore(currentWeekStart)) {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) return;
      final batch = firestore.batch();
      final groupRef = firestore.collection('groups').doc(group.id);

      batch.update(groupRef, {
        'weekStart': Timestamp.fromDate(currentWeekStart),
      });

      for (final member in members) {
        if (member.weeklyXP > 0) {
          final memberRef = groupRef.collection('members').doc(member.uid);
          batch.update(memberRef, {'weeklyXP': 0});
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error performing weekly XP reset: $e');
    }
  }
}

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
final groupStatsSummaryProvider =
    Provider.autoDispose.family<GroupStatsSummary, String>((ref, groupId) {
  final members = ref.watch(groupMembersStreamProvider(groupId)).value ?? [];
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
