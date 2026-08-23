import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/weekly_review_model.dart';
import '../services/weekly_review_service.dart';

/// Provider for WeeklyReviewService singleton.
final weeklyReviewServiceProvider = Provider<WeeklyReviewService>((ref) {
  return WeeklyReviewService();
});

/// Stream provider for the user's last completed weekly review date.
final lastReviewDateStreamProvider = StreamProvider<DateTime?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(weeklyReviewServiceProvider);
  return service.streamLastReviewDate(uid);
});

/// Stream provider for all past weekly reviews.
final weeklyReviewsStreamProvider =
    StreamProvider<List<WeeklyReviewModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(weeklyReviewServiceProvider);
  return service.streamWeeklyReviews(uid);
});

/// Computes whether a weekly review is currently due for the user.
///
/// Returns true if no review has ever been done or if >= 7 days have passed.
final isWeeklyReviewDueProvider = Provider<bool>((ref) {
  final lastReviewAsync = ref.watch(lastReviewDateStreamProvider);
  return lastReviewAsync.when(
    data: (date) => isReviewDue(date),
    loading: () => false,
    error: (err, stack) => false,
  );
});
