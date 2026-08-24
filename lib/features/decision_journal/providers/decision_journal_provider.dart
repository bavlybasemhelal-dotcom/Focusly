import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/decision_model.dart';
import '../services/decision_journal_service.dart';

/// Provider for DecisionJournalService singleton.
final decisionJournalServiceProvider = Provider<DecisionJournalService>((ref) {
  return DecisionJournalService();
});

/// Stream provider for user's decision journal logs.
/// Strictly scoped to current authenticated user for data isolation.
final decisionsStreamProvider = StreamProvider<List<DecisionModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(decisionJournalServiceProvider);
  return service.streamDecisions(uid);
});

/// Stats data class for summary cards (Pending Review vs. Reviewed Decisions).
class DecisionJournalStats {
  final int totalCount;
  final int pendingCount;
  final int reviewedCount;

  const DecisionJournalStats({
    required this.totalCount,
    required this.pendingCount,
    required this.reviewedCount,
  });
}

/// Derived provider computing counts of Pending Review and Reviewed decisions.
final decisionStatsProvider = Provider<DecisionJournalStats>((ref) {
  final decisionsAsync = ref.watch(decisionsStreamProvider);
  final decisions = decisionsAsync.value ?? [];

  int pending = 0;
  int reviewed = 0;

  for (final d in decisions) {
    if (d.reviewed) {
      reviewed++;
    } else {
      pending++;
    }
  }

  return DecisionJournalStats(
    totalCount: decisions.length,
    pendingCount: pending,
    reviewedCount: reviewed,
  );
});

/// Filter state enum for viewing decisions.
enum DecisionFilter {
  all,
  pending,
  reviewed,
}

/// Notifier managing active filter for Decision Journal screen.
class DecisionFilterNotifier extends Notifier<DecisionFilter> {
  @override
  DecisionFilter build() => DecisionFilter.all;

  void setFilter(DecisionFilter filter) {
    state = filter;
  }
}

final decisionFilterProvider =
    NotifierProvider<DecisionFilterNotifier, DecisionFilter>(
  DecisionFilterNotifier.new,
);

/// Derived provider returning decisions filtered by the active [DecisionFilter].
final filteredDecisionsProvider = Provider<List<DecisionModel>>((ref) {
  final decisionsAsync = ref.watch(decisionsStreamProvider);
  final decisions = decisionsAsync.value ?? [];
  final filter = ref.watch(decisionFilterProvider);

  switch (filter) {
    case DecisionFilter.all:
      return decisions;
    case DecisionFilter.pending:
      return decisions.where((d) => !d.reviewed).toList();
    case DecisionFilter.reviewed:
      return decisions.where((d) => d.reviewed).toList();
  }
});
