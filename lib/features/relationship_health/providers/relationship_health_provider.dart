import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/relationship_log_model.dart';
import '../services/relationship_health_service.dart';

/// Provider exposing RelationshipHealthService singleton.
final relationshipHealthServiceProvider = Provider<RelationshipHealthService>((
  ref,
) {
  return RelationshipHealthService();
});

/// Stream provider for all relationship interaction logs belonging to the user.
///
/// Strictly scoped to `users/{uid}/relationshipLogs`.
final relationshipLogsStreamProvider =
    StreamProvider<List<RelationshipLogModel>>((ref) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null || uid.isEmpty) return const Stream.empty();

      final service = ref.watch(relationshipHealthServiceProvider);
      return service.streamLogs(uid);
    });

/// Derived provider: The 8 most recent logged interactions across all contacts.
final recentInteractionsProvider = Provider<List<RelationshipLogModel>>((ref) {
  final logs = ref.watch(relationshipLogsStreamProvider).value ?? [];
  return logs.take(8).toList();
});
