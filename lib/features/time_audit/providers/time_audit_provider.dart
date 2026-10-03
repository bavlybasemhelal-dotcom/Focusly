import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/time_audit_model.dart';
import '../services/time_audit_service.dart';

/// Provider for TimeAuditService singleton.
final timeAuditServiceProvider = Provider<TimeAuditService>((ref) {
  return TimeAuditService();
});

/// Stream provider for user's manual time audit logs.
final timeAuditLogsStreamProvider = StreamProvider<List<TimeAuditLogModel>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(timeAuditServiceProvider);
  return service.streamLogs(uid);
});

/// State notifier managing the active period filter for Time Audit ('week' | 'month' | 'all').
class TimeAuditPeriodFilterNotifier extends Notifier<String> {
  @override
  String build() => 'week';

  void setPeriod(String period) {
    state = period;
  }
}

final timeAuditPeriodFilterProvider =
    NotifierProvider<TimeAuditPeriodFilterNotifier, String>(
      TimeAuditPeriodFilterNotifier.new,
    );

/// Structured data class representing combined stats for Time Audit.
class CombinedTimeAuditStats {
  final Map<String, double> categoryHours;
  final double totalHours;
  final List<String> sortedCategories;
  final String period;

  const CombinedTimeAuditStats({
    required this.categoryHours,
    required this.totalHours,
    required this.sortedCategories,
    required this.period,
  });

  double getPercentage(String categoryId) {
    if (totalHours <= 0) return 0.0;
    final hours = categoryHours[categoryId] ?? 0.0;
    return (hours / totalHours) * 100;
  }
}

/// Derived provider computing combined hours (manual logs + completed tasks heuristic)
/// grouped by category for the currently selected period.
final combinedTimeAuditStatsProvider = Provider<CombinedTimeAuditStats>((ref) {
  final logsAsync = ref.watch(timeAuditLogsStreamProvider);
  final tasksAsync = ref.watch(tasksStreamProvider);
  final period = ref.watch(timeAuditPeriodFilterProvider);

  final logs = logsAsync.value ?? [];
  final tasks = tasksAsync.value ?? [];
  final completedTasks = tasks.where((t) => t.done).toList();

  final categoryHours = computeCombinedCategoryHours(
    logs: logs,
    completedTasks: completedTasks,
    period: period,
  );

  double total = 0.0;
  categoryHours.forEach((_, hours) => total += hours);
  total = (total * 10).round() / 10.0;

  final sortedCats = categoryHours.keys.toList()
    ..sort((a, b) {
      final hoursA = categoryHours[a] ?? 0.0;
      final hoursB = categoryHours[b] ?? 0.0;
      return hoursB.compareTo(hoursA); // descending
    });

  return CombinedTimeAuditStats(
    categoryHours: categoryHours,
    totalHours: total,
    sortedCategories: sortedCats,
    period: period,
  );
});

/// Derived provider returning manual logs filtered by active period.
final filteredManualLogsProvider = Provider<List<TimeAuditLogModel>>((ref) {
  final logsAsync = ref.watch(timeAuditLogsStreamProvider);
  final period = ref.watch(timeAuditPeriodFilterProvider);
  final logs = logsAsync.value ?? [];

  return logs.where((l) => isDateInPeriod(l.date, period)).toList();
});
