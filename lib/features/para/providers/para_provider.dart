import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/para_area_model.dart';
import '../models/para_project_model.dart';
import '../models/para_resource_model.dart';
import '../services/para_service.dart';

/// Provides the singleton instance of ParaService
final paraServiceProvider = Provider<ParaService>((ref) {
  return ParaService();
});

/// Real-time stream of all PARA Areas for the authenticated user
final paraAreasStreamProvider = StreamProvider.autoDispose<List<ParaAreaModel>>(
  (ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('paraAreas')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ParaAreaModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  },
);

/// Raw stream of all PARA Projects for the user
final allParaProjectsStreamProvider =
    StreamProvider.autoDispose<List<ParaProjectModel>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) {
        return Stream.value([]);
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paraProjects')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ParaProjectModel.fromMap(doc.data(), doc.id))
                .toList();
          });
    });

/// Active (non-archived) PARA Projects stream provider
final paraProjectsStreamProvider =
    Provider.autoDispose<AsyncValue<List<ParaProjectModel>>>((ref) {
      final allProjectsAsync = ref.watch(allParaProjectsStreamProvider);
      return allProjectsAsync.whenData(
        (projects) => projects.where((p) => !p.archived).toList(),
      );
    });

/// Archived PARA Projects stream provider
final archivedProjectsStreamProvider =
    Provider.autoDispose<AsyncValue<List<ParaProjectModel>>>((ref) {
      final allProjectsAsync = ref.watch(allParaProjectsStreamProvider);
      return allProjectsAsync.whenData(
        (projects) => projects.where((p) => p.archived).toList(),
      );
    });

/// Raw stream of all PARA Resources for the user
final allParaResourcesStreamProvider =
    StreamProvider.autoDispose<List<ParaResourceModel>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) {
        return Stream.value([]);
      }

      return FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('paraResources')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => ParaResourceModel.fromMap(doc.data(), doc.id))
                .toList();
          });
    });

/// Active (non-archived) PARA Resources stream provider
final paraResourcesStreamProvider =
    Provider.autoDispose<AsyncValue<List<ParaResourceModel>>>((ref) {
      final allResourcesAsync = ref.watch(allParaResourcesStreamProvider);
      return allResourcesAsync.whenData(
        (resources) => resources.where((r) => !r.archived).toList(),
      );
    });

/// Archived PARA Resources stream provider
final archivedResourcesStreamProvider =
    Provider.autoDispose<AsyncValue<List<ParaResourceModel>>>((ref) {
      final allResourcesAsync = ref.watch(allParaResourcesStreamProvider);
      return allResourcesAsync.whenData(
        (resources) => resources.where((r) => r.archived).toList(),
      );
    });

/// Active projects count for a specific Area ID
final areaActiveProjectsCountProvider = Provider.autoDispose
    .family<int, String>((ref, areaId) {
      final projectsAsync = ref.watch(paraProjectsStreamProvider);
      return projectsAsync.when(
        data: (projects) =>
            projects.where((p) => p.areaId == areaId && !p.archived).length,
        loading: () => 0,
        error: (err, stack) => 0,
      );
    });

/// Tasks linked to a specific Project ID
final projectTasksProvider = Provider.autoDispose
    .family<List<TaskModel>, String>((ref, projectId) {
      final tasksAsync = ref.watch(tasksStreamProvider);
      return tasksAsync.when(
        data: (tasks) => tasks.where((t) => t.projectId == projectId).toList(),
        loading: () => [],
        error: (err, stack) => [],
      );
    });
