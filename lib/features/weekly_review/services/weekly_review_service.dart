import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/completion_ledger.dart';
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
    return _reviewsCollection(
      uid,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
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

      if (validPriorities.length > 3) return false;
      final reviewDocRef = _reviewsCollection(
        uid,
      ).doc(CompletionLedger.weekKey(now));
      final review = WeeklyReviewModel(
        id: reviewDocRef.id,
        date: now,
        priorities: validPriorities,
        createdAt: now,
      );
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reviewDocRef);
        if (existing.exists) return;
        transaction.set(reviewDocRef, review.toMap());
        for (var index = 0; index < validPriorities.length; index++) {
          final document = _inboxCollection(
            uid,
          ).doc('review_${reviewDocRef.id}_$index');
          transaction.set(
            document,
            InboxItemModel(
              id: document.id,
              text: '$priorityPrefix ${validPriorities[index]}'.trim(),
              processed: false,
              createdAt: now,
            ).toMap(),
          );
        }
        transaction.set(_metaReviewDoc(uid), {
          'lastReviewDate': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });

      // 4. Award XP for completing Weekly Review
      {
        await ProgressService(firestore: _firestore).awardXp(
          XpConstants.weeklyReview,
          source: 'Weekly review completed',
          sourceType: 'weekly_review',
          uid: uid,
          sourceId: reviewDocRef.id,
          eventId: 'weekly_review_${reviewDocRef.id}',
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
