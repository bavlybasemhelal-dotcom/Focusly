import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../../workout_tracker/providers/workout_provider.dart';
import '../../reading_tracker/providers/reading_provider.dart';
import '../../energy_mood/providers/energy_mood_provider.dart';
import '../models/annual_review_model.dart';
import '../services/annual_review_service.dart';
import '../services/year_stats_calculator.dart';

/// Provider exposing the Firestore service for Annual Reviews
final annualReviewServiceProvider = Provider<AnnualReviewService>((ref) {
  return AnnualReviewService();
});

/// Real-time stream of all Annual Reviews for the active authenticated user,
/// ordered by year descending.
final annualReviewsStreamProvider =
    StreamProvider.autoDispose<List<AnnualReviewModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(<AnnualReviewModel>[]);
  }
  final service = ref.watch(annualReviewServiceProvider);
  return service.getReviewsStream(uid);
});

/// Derived provider computing live yearly productivity stats for a specific [year]
final yearStatsProvider =
    Provider.family.autoDispose<YearStatsData, int>((ref, year) {
  final tasks = ref.watch(tasksStreamProvider).value ?? [];
  final workouts = ref.watch(workoutsStreamProvider).value ?? [];
  final books = ref.watch(booksStreamProvider).value ?? [];
  final checkins = ref.watch(checkinsHistoryStreamProvider).value ?? [];

  return calculateYearStats(
    year,
    tasks: tasks,
    workouts: workouts,
    books: books,
    checkins: checkins,
  );
});
