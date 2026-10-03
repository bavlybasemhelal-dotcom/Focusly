import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/nutrition_log_helpers.dart';
import '../models/nutrition_log_model.dart';
import '../services/nutrition_log_service.dart';

/// Provider exposing NutritionLogService singleton.
final nutritionLogServiceProvider = Provider<NutritionLogService>((ref) {
  return NutritionLogService();
});

/// Stream provider for all nutrition logs belonging to the authenticated user.
///
/// Strictly isolated to `users/{uid}/nutritionLog`.
final nutritionLogsStreamProvider = StreamProvider<List<NutritionLogModel>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(nutritionLogServiceProvider);
  return service.streamNutritionLogs(uid);
});

/// Derived provider: The 15 most recent nutrition log entries in reverse-chronological order.
final nutritionHistoryListProvider = Provider<List<NutritionLogModel>>((ref) {
  final logs = ref.watch(nutritionLogsStreamProvider).value ?? [];
  return logs.take(15).toList();
});

/// Derived provider: 7-day timeline cells (oldest on left, today on right).
final nutrition7DayTimelineProvider = Provider<List<NutritionDayCell>>((ref) {
  final logs = ref.watch(nutritionLogsStreamProvider).value ?? [];
  return NutritionLogHelpers.compute7DayTimeline(logs);
});

/// Derived provider: Week-over-week rating averages comparison.
final nutritionWeeklyComparisonProvider = Provider<NutritionWeeklyComparison>((
  ref,
) {
  final logs = ref.watch(nutritionLogsStreamProvider).value ?? [];
  return NutritionLogHelpers.computeWeeklyComparison(logs);
});
