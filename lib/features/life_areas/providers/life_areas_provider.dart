import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import '../models/life_area_assessment_model.dart';
import '../services/life_areas_service.dart';

/// Provider exposing the Firestore service for Life Areas
final lifeAreasServiceProvider = Provider<LifeAreasService>((ref) {
  return LifeAreasService();
});

/// Real-time stream of all Wheel of Life assessments for the current authenticated user
final lifeAreasStreamProvider =
    StreamProvider.autoDispose<List<LifeAreaAssessmentModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) {
    return Stream.value(<LifeAreaAssessmentModel>[]);
  }
  final service = ref.watch(lifeAreasServiceProvider);
  return service.getAssessmentsStream(uid);
});

/// Notifier tracking the currently selected Primary assessment ID
class SelectedPrimaryAssessmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
  }
}

final selectedPrimaryAssessmentIdProvider =
    NotifierProvider<SelectedPrimaryAssessmentNotifier, String?>(
  SelectedPrimaryAssessmentNotifier.new,
);

/// Notifier tracking the currently selected Comparison assessment ID (null = No Comparison)
class SelectedCompareAssessmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) {
    state = id;
  }
}

final selectedCompareAssessmentIdProvider =
    NotifierProvider<SelectedCompareAssessmentNotifier, String?>(
  SelectedCompareAssessmentNotifier.new,
);

/// Derived provider resolving the active Primary assessment model
final activePrimaryAssessmentProvider =
    Provider.autoDispose<LifeAreaAssessmentModel?>((ref) {
  final assessments = ref.watch(lifeAreasStreamProvider).value ?? [];
  if (assessments.isEmpty) return null;

  final selectedId = ref.watch(selectedPrimaryAssessmentIdProvider);
  if (selectedId == null) {
    // Defaults to the latest assessment (first in sorted list)
    return assessments.first;
  }

  return assessments.firstWhere(
    (a) => a.id == selectedId,
    orElse: () => assessments.first,
  );
});

/// Derived provider resolving the active Comparison assessment model
final activeCompareAssessmentProvider =
    Provider.autoDispose<LifeAreaAssessmentModel?>((ref) {
  final assessments = ref.watch(lifeAreasStreamProvider).value ?? [];
  if (assessments.isEmpty) return null;

  final selectedId = ref.watch(selectedCompareAssessmentIdProvider);
  if (selectedId == null) return null;

  final primary = ref.watch(activePrimaryAssessmentProvider);
  // Prevent comparing assessment with itself
  if (primary != null && primary.id == selectedId) return null;

  try {
    return assessments.firstWhere((a) => a.id == selectedId);
  } catch (_) {
    return null;
  }
});
