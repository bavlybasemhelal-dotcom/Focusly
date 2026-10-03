import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/challenge_model.dart';
import '../models/challenge_participant_model.dart';
import 'group_feed_service.dart';
import 'challenge_events_service.dart';

/// Service managing Challenge creation, participant registration, progress synchronization,
/// and automated expiration resolution.
class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final GroupFeedService _feedService = GroupFeedService();

  Timer? _debounceSyncTimer;

  /// Helper to fetch current user's stat value for a given challenge type
  Future<int> getCurrentUserStat(String type) async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    if (uid == null || uid.isEmpty) return 0;

    final firestore = _firestore;
    if (firestore == null) return 0;

    try {
      if (type == 'tasks') {
        final snap = await firestore
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .where('done', isEqualTo: true)
            .get();
        return snap.docs.length;
      } else if (type == 'habits') {
        final snap = await firestore
            .collection('users')
            .doc(uid)
            .collection('habits')
            .get();
        int completedDays = 0;
        for (final doc in snap.docs) {
          final days = List<bool>.from(doc.data()['days'] ?? []);
          completedDays += days.where((d) => d == true).length;
        }
        return completedDays;
      }
      // NOTE: 'xp' challenge type has been removed from Group Challenges.
      // Personal XP tracking is unaffected and remains active elsewhere.
    } catch (e) {
      debugPrint('Error getting stat for $type: $e');
    }
    return 0;
  }

  /// Creates a new Challenge and posts an announcement to the group feed
  Future<ChallengeModel?> createChallenge({
    required String groupId,
    required String title,
    required String type,
    required int goal,
    required int durationDays,
  }) async {
    String? uid;
    String name = 'Member';
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid = user?.uid;
      name = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'Member';
    } catch (_) {}

    if (uid == null || uid.isEmpty) return null;

    final firestore = _firestore;
    if (firestore == null) return null;

    try {
      final now = DateTime.now();
      final endDate = now.add(Duration(days: durationDays));

      final challengeRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc();

      final challenge = ChallengeModel(
        id: challengeRef.id,
        title: title.trim(),
        type: type,
        goal: goal,
        durationDays: durationDays,
        startDate: now,
        endDate: endDate,
        status: 'active',
        createdBy: uid,
        createdByName: name,
        participantCount: 1,
      );

      // Baseline for creator
      const baseline = 0;

      final participant = ChallengeParticipantModel(
        uid: uid,
        name: name,
        joinedAt: now,
        score: 0,
        baseline: baseline,
      );

      final batch = firestore.batch();
      batch.set(challengeRef, challenge.toMap());
      batch.set(
        challengeRef.collection('participants').doc(uid),
        participant.toMap(),
      );

      await batch.commit();

      // Post to group feed
      await _feedService.postToGroup(
        groupId: groupId,
        type: 'challenge_created',
        message: '$name launched a new challenge: $title! 🚀',
        icon: challenge.typeEmoji,
      );

      return challenge;
    } catch (e) {
      debugPrint('Error creating challenge: $e');
      return null;
    }
  }

  /// Joins an existing challenge, capturing current stat baseline
  Future<bool> joinChallenge({
    required String groupId,
    required String challengeId,
    required String type,
  }) async {
    String? uid;
    String name = 'Member';
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid = user?.uid;
      name = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'Member';
    } catch (_) {}

    if (uid == null || uid.isEmpty) return false;

    final firestore = _firestore;
    if (firestore == null) return false;

    try {
      final challengeRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('challenges')
          .doc(challengeId);

      final participantRef = challengeRef.collection('participants').doc(uid);

      final participantDoc = await participantRef.get();
      if (participantDoc.exists) return true; // Already joined

      const baseline = 0;

      final participant = ChallengeParticipantModel(
        uid: uid,
        name: name,
        joinedAt: DateTime.now(),
        score: 0,
        baseline: baseline,
      );

      await firestore.runTransaction((transaction) async {
        final challengeSnap = await transaction.get(challengeRef);
        final existingParticipant = await transaction.get(participantRef);
        if (existingParticipant.exists) return;
        if (!challengeSnap.exists ||
            challengeSnap.data()?['status'] != 'active' ||
            DateTime.now().isAfter(
              (challengeSnap.data()!['endDate'] as Timestamp).toDate(),
            )) {
          throw StateError('Challenge is no longer active');
        }

        final currentCount =
            (challengeSnap.data()?['participantCount'] as num?)?.toInt() ?? 0;

        transaction.set(participantRef, participant.toMap());
        transaction.update(challengeRef, {
          'participantCount': currentCount + 1,
        });
      });

      return true;
    } catch (e) {
      debugPrint('Error joining challenge: $e');
      return false;
    }
  }

  /// Debounced synchronization of user challenge progress when tasks/habits/XP change
  void triggerProgressSync({String? uid}) {
    final capturedUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
    _debounceSyncTimer?.cancel();
    _debounceSyncTimer = Timer(const Duration(seconds: 2), () {
      syncAllActiveChallenges(uid: capturedUid);
    });
  }

  /// Synchronizes user scores across all active challenges in all groups
  Future<void> syncAllActiveChallenges({String? uid}) async {
    try {
      uid ??= FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    if (uid == null || uid.isEmpty) return;

    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final userDoc = await firestore.collection('users').doc(uid).get();
      final groupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);
      if (groupIds.isEmpty) return;

      final scorer = ChallengeEventsService(firestore);
      for (final groupId in groupIds) {
        final challenges = await firestore
            .collection('groups')
            .doc(groupId)
            .collection('challenges')
            .where('status', isEqualTo: 'active')
            .get();
        for (final challenge in challenges.docs) {
          await scorer.syncParticipant(
            groupId: groupId,
            challengeId: challenge.id,
            uid: uid,
          );
        }
      }
    } catch (e) {
      debugPrint('Error syncing challenges: $e');
    }
  }

  /// Evaluates active challenges in a group; marks expired ones as finished and crowns winner
  Future<String?> evaluateAutoFinish({
    required String groupId,
    required List<ChallengeModel> challenges,
  }) async {
    final now = DateTime.now();
    String? currentUid;
    try {
      currentUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    final firestore = _firestore;
    if (firestore == null) return null;

    if (currentUid == null) return null;
    final group = await firestore.collection('groups').doc(groupId).get();
    final member = await firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(currentUid)
        .get();
    if (group.data()?['createdBy'] != currentUid &&
        !(member.data()?['status'] == 'approved' &&
            member.data()?['role'] == 'admin')) {
      return null;
    }

    String? wonChallengeTitleForCurrentUser;

    for (final challenge in challenges) {
      if (challenge.isActive && now.isAfter(challenge.endDate)) {
        try {
          final challengeRef = firestore
              .collection('groups')
              .doc(groupId)
              .collection('challenges')
              .doc(challenge.id);

          final registered = await challengeRef
              .collection('participants')
              .get();
          for (final participant in registered.docs) {
            await ChallengeEventsService(firestore).syncParticipant(
              groupId: groupId,
              challengeId: challenge.id,
              uid: participant.id,
            );
          }
          final participantsSnap = await challengeRef
              .collection('participants')
              .orderBy('score', descending: true)
              .get();

          String? winnerUid;
          String? winnerName;
          int winnerScore = 0;

          if (participantsSnap.docs.isNotEmpty &&
              (participantsSnap.docs.first.data()['score'] as num).toInt() >=
                  challenge.goal) {
            final topDoc = participantsSnap.docs.first;
            winnerUid = topDoc.data()['uid'] ?? topDoc.id;
            winnerName = topDoc.data()['name'] ?? 'Member';
            winnerScore = (topDoc.data()['score'] as num?)?.toInt() ?? 0;
          }

          final Map<String, dynamic> updateData = {
            'status': 'finished',
            'winnerScore': winnerScore,
          };
          final tied = participantsSnap.docs
              .where(
                (document) =>
                    (document.data()['score'] as num).toInt() == winnerScore &&
                    winnerScore >= challenge.goal,
              )
              .toList();
          updateData['winnerUids'] = tied
              .map((document) => document.id)
              .toList();
          if (tied.length > 1) {
            winnerUid = null;
            winnerName = tied
                .map((document) => document.data()['name'] as String)
                .join(', ');
          }
          updateData['approvedBy'] = currentUid;
          updateData['approvedAt'] = FieldValue.serverTimestamp();
          if (winnerUid != null) updateData['winnerUid'] = winnerUid;
          if (winnerName != null) updateData['winnerName'] = winnerName;

          await firestore.runTransaction((transaction) async {
            final fresh = await transaction.get(challengeRef);
            if (fresh.data()?['status'] != 'active') return;
            transaction.update(challengeRef, updateData);
          });

          if (winnerName != null && winnerName.isNotEmpty) {
            await _feedService.postToGroup(
              groupId: groupId,
              type: 'challenge_won',
              message:
                  '🏆 $winnerName won the "${challenge.title}" challenge with $winnerScore points!',
              icon: '👑',
            );
          }

          if (winnerUid != null && winnerUid == currentUid) {
            wonChallengeTitleForCurrentUser = challenge.title;
          }
        } catch (e) {
          debugPrint('Error finalizing challenge: $e');
          rethrow;
        }
      }
    }

    return wonChallengeTitleForCurrentUser;
  }
}
