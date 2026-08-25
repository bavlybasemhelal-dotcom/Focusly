import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/annual_review_model.dart';

/// Isolated Firestore service for managing Annual Reviews under `users/{uid}/annualReviews`.
class AnnualReviewService {
  final FirebaseFirestore _firestore;

  AnnualReviewService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('annualReviews');
  }

  /// Real-time stream of all Annual Reviews for a user, sorted by year descending
  Stream<List<AnnualReviewModel>> getReviewsStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection(uid)
        .orderBy('year', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AnnualReviewModel.fromFirestore(doc))
          .toList();
    }).handleError((_) => <AnnualReviewModel>[]);
  }

  /// Adds a new annual review entry and returns the generated document ID
  Future<String> addReview(String uid, AnnualReviewModel review) async {
    final docRef = await _collection(uid).add(review.toMap());
    return docRef.id;
  }

  /// Updates an existing annual review entry
  Future<void> updateReview(String uid, AnnualReviewModel review) async {
    await _collection(uid).doc(review.id).update(review.toMap());
  }

  /// Deletes an annual review entry
  Future<void> deleteReview(String uid, String reviewId) async {
    await _collection(uid).doc(reviewId).delete();
  }
}
