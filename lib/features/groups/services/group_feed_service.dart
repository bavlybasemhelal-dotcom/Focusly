import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_feed_model.dart';

/// Shared service for broadcasting group feed activity and managing atomic emoji reactions.
class GroupFeedService {
  static final GroupFeedService _instance = GroupFeedService._internal();
  factory GroupFeedService() => _instance;
  GroupFeedService._internal();

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Broadcasts an activity event (task milestone, streak, level up, challenge event)
  /// to all groups that the current user belongs to.
  Future<void> pushToAllUserGroups({
    required String type,
    required String message,
    required String icon,
    String? uid,
  }) async {
    String name = 'Member';
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid ??= user?.uid;
      if (user?.uid != uid) return;
      name = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'Member';
    } catch (_) {}

    if (uid == null || uid.isEmpty) return;

    final firestore = _firestore;
    if (firestore == null) return;

    try {
      // 1. Get all group IDs for user
      final userDoc = await firestore.collection('users').doc(uid).get();
      if (userDoc.data()?['sharePersonalActivity'] != true) return;
      // Personal titles stay private even when activity sharing is enabled.
      message = switch (type) {
        'task_milestone' => 'Completed a task 🎯',
        'habit_streak' => 'Made progress on a habit 🔥',
        'level_up' => 'Reached a new level ⭐',
        _ => 'Made progress 🌱',
      };
      final groupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);

      if (groupIds.isEmpty) return;

      final now = DateTime.now();

      // 2. Batch write feed entry into each group
      final batch = firestore.batch();
      for (final groupId in groupIds) {
        final feedRef = firestore
            .collection('groups')
            .doc(groupId)
            .collection('feed')
            .doc();

        final feedItem = GroupFeedModel(
          id: feedRef.id,
          uid: uid,
          name: name,
          type: type,
          message: message,
          icon: icon,
          reactions: const {'like': 0, 'fire': 0, 'clap': 0},
          reactedBy: const {},
          createdAt: now,
        );

        batch.set(feedRef, feedItem.toMap());
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error pushing feed items to groups: $e');
    }
  }

  /// Posts a feed item into a single specific group (e.g. on challenge creation)
  Future<void> postToGroup({
    required String groupId,
    required String type,
    required String message,
    required String icon,
    String? uid,
    String? eventId,
  }) async {
    String name = 'Member';
    try {
      final user = FirebaseAuth.instance.currentUser;
      uid ??= user?.uid;
      if (user?.uid != uid) return;
      name = user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!
          : 'Member';
    } catch (_) {}

    if (uid == null || uid.isEmpty) return;

    final firestore = _firestore;
    if (firestore == null) return;

    try {
      final feedRef = firestore
          .collection('groups')
          .doc(groupId)
          .collection('feed')
          .doc(eventId);

      final feedItem = GroupFeedModel(
        id: feedRef.id,
        uid: uid,
        name: name,
        type: type,
        message: message,
        icon: icon,
        reactions: const {'like': 0, 'fire': 0, 'clap': 0},
        reactedBy: const {},
        createdAt: DateTime.now(),
      );

      await firestore.runTransaction((transaction) async {
        final previous = await transaction.get(feedRef);
        if (!previous.exists) transaction.set(feedRef, feedItem.toMap());
      });
    } catch (e) {
      debugPrint('Error posting feed item: $e');
    }
  }

  /// Toggles a user's reaction (like, fire, clap) on a feed item using a Firestore transaction
  /// to safely prevent race conditions with multiple concurrent reactions.
  Future<void> toggleReaction({
    required String groupId,
    required String feedId,
    required String emojiType, // 'like' | 'fire' | 'clap'
  }) async {
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}

    if (uid == null || uid.isEmpty) return;

    final firestore = _firestore;
    if (firestore == null) return;

    final docRef = firestore
        .collection('groups')
        .doc(groupId)
        .collection('feed')
        .doc(feedId);

    try {
      await firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() ?? {};
        final rawReactions = data['reactions'] as Map<String, dynamic>? ?? {};
        final rawReactedBy = data['reactedBy'] as Map<String, dynamic>? ?? {};

        final reactions = Map<String, int>.from(
          rawReactions.map((k, v) => MapEntry(k, (v as num).toInt())),
        );
        final reactedBy = Map<String, String>.from(rawReactedBy);

        final previousReaction = reactedBy[uid];

        if (previousReaction == emojiType) {
          // User is removing their existing reaction
          reactedBy.remove(uid);
          reactions[emojiType] = ((reactions[emojiType] ?? 1) - 1).clamp(
            0,
            999999,
          );
        } else {
          // User is switching or adding a new reaction
          if (previousReaction != null) {
            reactions[previousReaction] =
                ((reactions[previousReaction] ?? 1) - 1).clamp(0, 999999);
          }
          reactedBy[uid!] = emojiType;
          reactions[emojiType] = (reactions[emojiType] ?? 0) + 1;
        }

        transaction.update(docRef, {
          'reactions': reactions,
          'reactedBy': reactedBy,
          'reactionUids': reactedBy.keys.toList(),
        });
      });
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
    }
  }

  /// Stores local timestamp when user views a group to compute unread badges
  Future<void> markGroupViewed(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'group_last_viewed_${FirebaseAuth.instance.currentUser?.uid}_$groupId',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Gets local timestamp when user last viewed a group
  Future<DateTime?> getGroupLastViewed(String groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final millis = prefs.getInt(
        'group_last_viewed_${FirebaseAuth.instance.currentUser?.uid}_$groupId',
      );
      if (millis != null) {
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    } catch (_) {}
    return null;
  }
}
