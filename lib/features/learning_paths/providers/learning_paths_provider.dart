import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/learning_path_model.dart';
import '../services/learning_paths_service.dart';

/// Provider for LearningPathsService singleton.
final learningPathsServiceProvider = Provider<LearningPathsService>((ref) {
  return LearningPathsService();
});

/// Stream provider for all learning paths for the active user.
///
/// Strictly scoped to `users/{uid}/learningPaths`.
final learningPathsStreamProvider = StreamProvider<List<LearningPathModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(learningPathsServiceProvider);
  return service.streamPaths(uid);
});

/// Notifier tracking expanded card IDs in the UI (local unpersisted UI state).
class ExpandedPathIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void toggleExpanded(String pathId) {
    final copy = Set<String>.from(state);
    if (copy.contains(pathId)) {
      copy.remove(pathId);
    } else {
      copy.add(pathId);
    }
    state = copy;
  }

  bool isExpanded(String pathId) => state.contains(pathId);
}

final expandedPathIdsProvider =
    NotifierProvider<ExpandedPathIdsNotifier, Set<String>>(
  ExpandedPathIdsNotifier.new,
);
