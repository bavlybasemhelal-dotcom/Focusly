import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/workout_helpers.dart';
import '../models/workout_model.dart';
import '../services/workout_service.dart';

/// Provider exposing WorkoutService singleton.
final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService();
});

/// Stream provider for all workouts belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/workouts`.
final workoutsStreamProvider = StreamProvider<List<WorkoutModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(workoutServiceProvider);
  return service.streamWorkouts(uid);
});

/// Derived provider: The 5 most recent workouts in reverse-chronological order.
final recentWorkoutsProvider = Provider<List<WorkoutModel>>((ref) {
  final workouts = ref.watch(workoutsStreamProvider).value ?? [];
  return workouts.take(5).toList();
});

/// Derived provider: This week's minutes, calories, and total count.
final workoutStatsProvider = Provider<WorkoutStats>((ref) {
  final workouts = ref.watch(workoutsStreamProvider).value ?? [];
  return WorkoutHelpers.calculateStats(workouts);
});

/// Derived provider: 30-day streak heatmap daily cells list.
final workoutHeatmapProvider = Provider<List<HeatmapDayInfo>>((ref) {
  final workouts = ref.watch(workoutsStreamProvider).value ?? [];
  return WorkoutHelpers.compute30DayHeatmap(workouts);
});
