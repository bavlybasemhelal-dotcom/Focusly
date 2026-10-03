import '../models/learning_path_model.dart';

/// Pure helpers for Learning Path step resizing, sub-step completion evaluation,
/// and bidirectional progress synchronization.
///
/// Contains NO side effects or external dependencies for 100% deterministic testability.
class LearningPathHelpers {
  /// Dynamically resizes a steps list to [newTotalDays] while preserving
  /// all existing per-day data (title, completed state, sub-steps) keyed by day number.
  ///
  /// Example:
  /// - Changing totalDays from 30 to 45 preserves Days 1..30 and appends blank Days 31..45.
  /// - Changing totalDays from 30 to 15 keeps Days 1..15 and truncates Days 16..30.
  static List<PathStepModel> resizeSteps(
    List<PathStepModel> existingSteps,
    int newTotalDays,
  ) {
    final validTotalDays = newTotalDays > 0 ? newTotalDays : 1;

    // Index existing steps by day number (1-based)
    final Map<int, PathStepModel> stepMap = {};
    for (final s in existingSteps) {
      stepMap[s.day] = s;
    }

    final List<PathStepModel> result = [];
    for (int d = 1; d <= validTotalDays; d++) {
      if (stepMap.containsKey(d)) {
        result.add(stepMap[d]!);
      } else {
        result.add(
          PathStepModel(
            day: d,
            title: '',
            completed: false,
            subSteps: const [],
          ),
        );
      }
    }

    return result;
  }

  /// Determines whether a day step is completed based on its sub-steps.
  ///
  /// Rules:
  /// - If the step has sub-steps, it is considered complete if and only if
  ///   ALL sub-steps are marked completed.
  /// - If the step has no sub-steps, it retains its manual completion state.
  static bool evaluateDayCompletion(PathStepModel step) {
    if (step.subSteps.isNotEmpty) {
      return step.subSteps.every((sub) => sub.completed);
    }
    return step.completed;
  }

  /// Synchronizes all steps' completion statuses and computes `progressDay`.
  static LearningPathModel syncPathProgress(LearningPathModel path) {
    final updatedSteps = path.steps.map((step) {
      final isDone = evaluateDayCompletion(step);
      if (isDone != step.completed) {
        return step.copyWith(completed: isDone);
      }
      return step;
    }).toList();

    final completedCount = updatedSteps.where((s) => s.completed).length;

    return path.copyWith(steps: updatedSteps, progressDay: completedCount);
  }
}
