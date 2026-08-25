import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bucket_item_model.dart';

/// Isolated Firestore service for managing Bucket List items under `users/{uid}/bucketList`.
class BucketListService {
  final FirebaseFirestore _firestore;

  BucketListService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('bucketList');
  }

  /// Real-time stream of all bucket list items for a user, ordered by creation date descending
  Stream<List<BucketItemModel>> getBucketItemsStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BucketItemModel.fromFirestore(doc))
          .toList();
    }).handleError((_) => <BucketItemModel>[]);
  }

  /// Adds a new bucket list item and returns generated document ID
  Future<String> addBucketItem(String uid, BucketItemModel item) async {
    final docRef = await _collection(uid).add(item.toMap());
    return docRef.id;
  }

  /// Updates an existing bucket list item
  Future<void> updateBucketItem(String uid, BucketItemModel item) async {
    await _collection(uid).doc(item.id).update(item.toMap());
  }

  /// Deletes a bucket list item
  Future<void> deleteBucketItem(String uid, String itemId) async {
    await _collection(uid).doc(itemId).delete();
  }

  /// Quickly marks a pending dream as completed
  Future<BucketItemModel> markItemCompleted(String uid, BucketItemModel item) async {
    final updated = item.copyWith(
      status: 'completed',
      updatedAt: DateTime.now(),
    );
    await updateBucketItem(uid, updated);
    return updated;
  }
}
