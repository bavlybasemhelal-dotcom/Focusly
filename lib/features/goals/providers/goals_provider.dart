import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/goal_model.dart';
import '../services/goals_service.dart';

/// Provider exposing the singleton GoalsService.
final goalsServiceProvider = Provider<GoalsService>((ref) {
  return GoalsService();
});

/// Real-time stream of all goals for the current user.
final goalsStreamProvider = StreamProvider<List<GoalModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  final service = ref.watch(goalsServiceProvider);
  return service.streamGoals(uid);
});

/// Provider for a specific timeframe column ('1month' | '3months' | '1year' | '5years').
final goalsByTimeframeProvider = Provider.family<List<GoalModel>, String>((
  ref,
  timeframe,
) {
  final goalsAsync = ref.watch(goalsStreamProvider);
  final showCompleted = ref.watch(showCompletedGoalsProvider);
  final goals = goalsAsync.value ?? [];

  return goals.where((g) {
    if (g.timeframe != timeframe) return false;
    if (!showCompleted && g.isDone) return false;
    return true;
  }).toList();
});

/// Notifier managing whether completed goals are visible on the board.
class ShowCompletedGoalsNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
  }

  void setShowCompleted(bool show) {
    state = show;
  }
}

final showCompletedGoalsProvider =
    NotifierProvider<ShowCompletedGoalsNotifier, bool>(
      ShowCompletedGoalsNotifier.new,
    );

/// Notifier for the currently active timeframe tab on mobile board view.
class SelectedTimeframeTabNotifier extends Notifier<String> {
  @override
  String build() => '1month';

  void selectTab(String timeframe) {
    state = timeframe;
  }
}

final selectedTimeframeTabProvider =
    NotifierProvider<SelectedTimeframeTabNotifier, String>(
      SelectedTimeframeTabNotifier.new,
    );
