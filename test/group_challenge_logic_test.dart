import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/groups/models/challenge_model.dart';
import 'package:focusly/features/groups/models/challenge_participant_model.dart';
import 'package:focusly/features/groups/models/group_feed_model.dart';
import 'package:focusly/features/groups/models/group_member_model.dart';
import 'package:focusly/features/groups/models/group_model.dart';

void main() {
  group('Focusly Group & Challenge Logic Tests', () {
    test('GroupModel default values and user caps', () {
      final now = DateTime.now();
      final group = GroupModel(
        id: 'grp_1',
        name: 'Morning Squad',
        icon: '🚀',
        description: 'Focus and win',
        inviteCode: 'GRP-ABC123',
        createdBy: 'user_1',
        createdAt: now,
      );

      expect(group.memberCount, 1);
      expect(group.maxMembers, 20);
      expect(group.status, 'active');
      expect(GroupModel.maxGroupsPerUser, 5);
      expect(GroupModel.defaultMaxMembers, 20);
    });

    test('GroupMemberModel role and status helper getters', () {
      final admin = GroupMemberModel(
        uid: 'u1',
        name: 'Alex',
        role: 'admin',
        status: 'approved',
        requestedAt: DateTime.now(),
      );

      final pending = GroupMemberModel(
        uid: 'u2',
        name: 'Sam',
        role: 'member',
        status: 'pending',
        requestedAt: DateTime.now(),
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isApproved, isTrue);
      expect(admin.isPending, isFalse);

      expect(pending.isAdmin, isFalse);
      expect(pending.isApproved, isFalse);
      expect(pending.isPending, isTrue);
    });

    test('ChallengeModel durationDays and daysRemaining calculations', () {
      final now = DateTime.now();
      final activeChallenge = ChallengeModel(
        id: 'c1',
        title: '50 Tasks Sprint',
        type: 'tasks',
        goal: 50,
        durationDays: 7,
        startDate: now,
        endDate: now.add(const Duration(days: 7)),
        createdBy: 'u1',
        createdByName: 'Alex',
      );

      expect(activeChallenge.isActive, isTrue);
      expect(activeChallenge.isFinished, isFalse);
      expect(activeChallenge.typeEmoji, '🎯');
      expect(activeChallenge.typeTitleKey, 'challenge_type_tasks');
      expect(activeChallenge.daysRemaining, greaterThanOrEqualTo(6));

      final finishedChallenge = ChallengeModel(
        id: 'c2',
        title: 'XP Blitz',
        type: 'xp',
        goal: 500,
        durationDays: 3,
        startDate: now.subtract(const Duration(days: 5)),
        endDate: now.subtract(const Duration(days: 2)),
        status: 'finished',
        createdBy: 'u1',
        createdByName: 'Alex',
        winnerUid: 'u2',
        winnerName: 'Sam',
        winnerScore: 520,
      );

      expect(finishedChallenge.isFinished, isTrue);
      expect(finishedChallenge.daysRemaining, 0);
      expect(finishedChallenge.typeEmoji, '⚡');
    });

    test('ChallengeParticipantModel score calculation relative to baseline', () {
      final participant = ChallengeParticipantModel(
        uid: 'u1',
        name: 'Alex',
        joinedAt: DateTime.now(),
        score: 0,
        baseline: 15, // User had 15 completed tasks when joining
      );

      // Stat increases to 25 completed tasks
      final currentTasks = 25;
      final newScore = (currentTasks - participant.baseline).clamp(0, 9999);
      final updated = participant.copyWith(score: newScore);

      expect(updated.score, 10);
    });

    test('GroupFeedModel reaction counts and user reaction tracking', () {
      final feed = GroupFeedModel(
        id: 'f1',
        uid: 'u1',
        name: 'Alex',
        type: 'task_milestone',
        message: 'Completed task: Launch Focusly! 🎯',
        icon: '🎯',
        reactions: const {'like': 3, 'fire': 5, 'clap': 2},
        reactedBy: const {'u1': 'fire', 'u2': 'like'},
        createdAt: DateTime.now(),
      );

      expect(feed.likeCount, 3);
      expect(feed.fireCount, 5);
      expect(feed.clapCount, 2);
      expect(feed.getUserReaction('u1'), 'fire');
      expect(feed.getUserReaction('u2'), 'like');
      expect(feed.getUserReaction('u3'), isNull);
    });
  });
}
