import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../para/models/para_project_model.dart';
import '../../para/providers/para_provider.dart';
import '../models/retrospective_model.dart';
import '../services/retrospective_service.dart';

/// Provider for RetrospectiveService singleton instance.
final retrospectiveServiceProvider = Provider<RetrospectiveService>((ref) {
  return RetrospectiveService();
});

/// Real-time stream of all Project Retrospectives for the logged in user.
final retrospectivesStreamProvider = StreamProvider<List<RetrospectiveModel>>((
  ref,
) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(retrospectiveServiceProvider);
  return service.streamRetrospectives(uid);
});

/// Family provider resolving the project title for a given [projectId].
/// Returns null if not found (e.g. if the project was deleted).
final projectTitleResolverProvider = Provider.autoDispose
    .family<String?, String>((ref, projectId) {
      final allProjectsAsync = ref.watch(allParaProjectsStreamProvider);
      final projects = allProjectsAsync.value ?? [];

      for (final project in projects) {
        if (project.id == projectId) {
          return project.title;
        }
      }
      return null;
    });

/// Derived provider providing a map of projectId -> ParaProjectModel for fast lookup.
final paraProjectsMapProvider =
    Provider.autoDispose<Map<String, ParaProjectModel>>((ref) {
      final allProjectsAsync = ref.watch(allParaProjectsStreamProvider);
      final projects = allProjectsAsync.value ?? [];
      return {for (var p in projects) p.id: p};
    });
