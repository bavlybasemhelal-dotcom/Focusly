import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../gtd/models/inbox_item_model.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';
import '../models/weekly_review_model.dart';

/// Service handling Weekly Review persistence and dual-write to GTD Inbox.
///
/// DATA ISOLATION GUARANTEE:
/// All documents are stored strictly under `users/{uid}/...`
class WeeklyReviewService {
  final FirebaseFirestore _firestore;

  WeeklyReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reviewsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('weeklyReviews');
  }

  DocumentReference<Map<String, dynamic>> _metaReviewDoc(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('meta')
        .doc('weeklyReview');
  }

  CollectionReference<Map<String, dynamic>> _inboxCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('inbox');
  }

  /// Streams the date of the user's last completed weekly review.
  Stream<DateTime?> streamLastReviewDate(String uid) {
    return _metaReviewDoc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final raw = doc.data()!['lastReviewDate'];
      if (raw is Timestamp) {
        return raw.toDate();
      } else if (raw is String) {
        return DateTime.tryParse(raw);
      }
      return null;
    });
  }

  /// Streams all past weekly reviews ordered by createdAt descending.
  Stream<List<WeeklyReviewModel>> streamWeeklyReviews(String uid) {
    return _reviewsCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WeeklyReviewModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Completes the Weekly Review session.
  ///
  /// Dual-write behavior:
  /// 1. Saves `WeeklyReviewModel` to `users/{uid}/weeklyReviews/{id}`.
  /// 2. Creates a GTD Inbox item for each filled priority prefixed with [priorityPrefix]
  ///    (e.g., "Week priority: Ship v1.0") so it surfaces for standard GTD processing.
  /// 3. Updates `users/{uid}/meta/weeklyReview` with `lastReviewDate`.
  /// 4. Awards +40 XP via [ProgressService].
  Future<bool> finishWeeklyReview({
    required String uid,
    required List<String> priorities,
    required String priorityPrefix,
    WidgetRef? ref,
  }) async {
    try {
      final now = DateTime.now();
      final validPriorities = priorities
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      // 1. Save Weekly Review document
      final reviewDocRef = _reviewsCollection(uid).doc();
      final review = WeeklyReviewModel(
        id: reviewDocRef.id,
        date: now,
        priorities: validPriorities,
        createdAt: now,
      );
      await reviewDocRef.set(review.toMap());

      // 2. Dual-Write: Create GTD Inbox items for each priority
      for (final priority in validPriorities) {
        final inboxDocRef = _inboxCollection(uid).doc();
        final inboxItem = InboxItemModel(
          id: inboxDocRef.id,
          text: '$priorityPrefix $priority'.trim(),
          processed: false,
          createdAt: now,
        );
        await inboxDocRef.set(inboxItem.toMap());
      }

      // 3. Update last review date in user metadata
      await _metaReviewDoc(uid).set({
        'lastReviewDate': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      // 4. Award XP for completing Weekly Review
      if (ref != null) {
        await ProgressService().awardXp(
          XpConstants.weeklyReview,
          source: 'Weekly review completed',
          sourceType: 'weekly_review',
          ref: ref,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error finishing weekly review: $e');
      return false;
    }
  }
}
