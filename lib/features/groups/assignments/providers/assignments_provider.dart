import '../../../../core/auth/auth_provider.dart';
import '../../providers/groups_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment_completion_model.dart';
import '../models/group_assignment_model.dart';
import '../services/group_assignment_service.dart';

/// Stream of all assignments created for a specific group
final groupAssignmentsStreamProvider =
    StreamProvider.family<List<GroupAssignmentModel>, String>((ref, groupId) {
      if (ref.watch(currentUserIdProvider) == null || groupId.isEmpty) {
        return Stream.value([]);
      }

      try {
        final firestore = ref.watch(groupsFirestoreProvider);
        if (firestore == null) return Stream.value([]);
        return firestore
            .collection('groups')
            .doc(groupId)
            .collection('assignments')
            .orderBy('createdAt', descending: true)
            .snapshots()
            .map((snapshot) {
              return snapshot.docs
                  .map((doc) => GroupAssignmentModel.fromFirestore(doc))
                  .toList();
            });
      } catch (_) {
        return Stream.value([]);
      }
    });

/// Data holder combining Group ID and Assignment ID for family stream provider
class AssignmentRefParams {
  final String groupId;
  final String assignmentId;

  const AssignmentRefParams({
    required this.groupId,
    required this.assignmentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssignmentRefParams &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          assignmentId == other.assignmentId;

  @override
  int get hashCode => groupId.hashCode ^ assignmentId.hashCode;
}

/// Stream of individual member completion progress documents for a specific assignment
final assignmentCompletionsStreamProvider =
    StreamProvider.family<List<AssignmentCompletionModel>, AssignmentRefParams>(
      (ref, params) {
        if (ref.watch(currentUserIdProvider) == null ||
            params.groupId.isEmpty ||
            params.assignmentId.isEmpty) {
          return Stream.value([]);
        }

        try {
          final firestore = ref.watch(groupsFirestoreProvider);
          if (firestore == null) return Stream.value([]);
          return firestore
              .collection('groups')
              .doc(params.groupId)
              .collection('assignments')
              .doc(params.assignmentId)
              .collection('completions')
              .snapshots()
              .map((snapshot) {
                return snapshot.docs
                    .map((doc) => AssignmentCompletionModel.fromFirestore(doc))
                    .toList();
              });
        } catch (_) {
          return Stream.value([]);
        }
      },
    );

/// Provider for Group Assignment Service
final groupAssignmentServiceProvider = Provider<GroupAssignmentService>((ref) {
  return GroupAssignmentService();
});
