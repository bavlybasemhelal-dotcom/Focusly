import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../energy_mood/providers/energy_mood_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../helpers/life_analytics_helpers.dart';

/// Derived provider computing Life Analytics metrics reactively
/// by combining the user's Energy check-ins stream and Tasks stream.
final lifeAnalyticsSummaryProvider = Provider<LifeAnalyticsSummary>((ref) {
  final checkins = ref.watch(checkinsHistoryStreamProvider).value ?? [];
  final tasks = ref.watch(tasksStreamProvider).value ?? [];

  return LifeAnalyticsHelpers.computeSummary(
    checkins: checkins,
    tasks: tasks,
  );
});
