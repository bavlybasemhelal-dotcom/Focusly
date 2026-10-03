import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import '../models/bucket_item_model.dart';
import '../services/bucket_list_service.dart';

/// Provider exposing the Firestore service for Bucket List
final bucketListServiceProvider = Provider<BucketListService>((ref) {
  return BucketListService();
});

/// Real-time stream of all bucket list items for the active authenticated user
final bucketListStreamProvider =
    StreamProvider.autoDispose<List<BucketItemModel>>((ref) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null || uid.isEmpty) {
        return Stream.value(<BucketItemModel>[]);
      }
      final service = ref.watch(bucketListServiceProvider);
      return service.getBucketItemsStream(uid);
    });

/// Filtered provider for pending dreams to achieve
final pendingBucketItemsProvider = Provider.autoDispose<List<BucketItemModel>>((
  ref,
) {
  final allItems = ref.watch(bucketListStreamProvider).value ?? [];
  return allItems.where((i) => i.isPending).toList();
});

/// Filtered provider for achieved dreams with memories
final completedBucketItemsProvider =
    Provider.autoDispose<List<BucketItemModel>>((ref) {
      final allItems = ref.watch(bucketListStreamProvider).value ?? [];
      return allItems.where((i) => i.isCompleted).toList();
    });
