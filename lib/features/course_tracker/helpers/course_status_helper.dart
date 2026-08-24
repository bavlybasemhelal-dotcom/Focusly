import '../models/course_model.dart';

/// Result object from normalizing a course's progress and auto-status.
class CourseProgressResult {
  final int totalLessons;
  final int completedLessons;
  final String status;
  final bool isNewlyCompleted;

  const CourseProgressResult({
    required this.totalLessons,
    required this.completedLessons,
    required this.status,
    required this.isNewlyCompleted,
  });
}

/// Pure helper functions for Course lesson clamping and bidirectional auto-status rules.
///
/// Contains NO side effects or external dependencies for 100% deterministic testability.
class CourseStatusHelper {
  /// Normalizes lesson counts and evaluates auto-status transitions:
  /// - Total lessons is clamped to a minimum of 1.
  /// - Completed lessons is clamped between 0 and [totalLessons].
  /// - When completed lessons reaches total lessons, status automatically becomes 'completed'.
  /// - When completed lessons falls below total lessons and status was 'completed',
  ///   status automatically reverts back to 'active'.
  /// - Otherwise, preserves [manualStatus] ('active' | 'paused').
  static CourseProgressResult normalizeCourseProgress({
    required int totalLessons,
    required int completedLessons,
    required String manualStatus,
    String? previousStatus,
  }) {
    final validTotal = totalLessons > 0 ? totalLessons : 1;
    final validCompleted = completedLessons.clamp(0, validTotal);

    String finalStatus = manualStatus.trim().toLowerCase();
    if (finalStatus != 'active' && finalStatus != 'paused' && finalStatus != 'completed') {
      finalStatus = 'active';
    }

    if (validCompleted >= validTotal) {
      finalStatus = 'completed';
    } else if (finalStatus == 'completed') {
      // Revert to active if incomplete
      finalStatus = 'active';
    }

    final isNewlyCompleted = finalStatus == 'completed' && previousStatus != 'completed';

    return CourseProgressResult(
      totalLessons: validTotal,
      completedLessons: validCompleted,
      status: finalStatus,
      isNewlyCompleted: isNewlyCompleted,
    );
  }

  /// Adjusts a course's completed lessons count by [delta] (+1 or -1) and applies auto-status.
  static CourseModel adjustCompletedLessons(CourseModel course, int delta) {
    final targetCompleted = course.completedLessons + delta;
    final normalized = normalizeCourseProgress(
      totalLessons: course.totalLessons,
      completedLessons: targetCompleted,
      manualStatus: course.status,
      previousStatus: course.status,
    );

    return course.copyWith(
      completedLessons: normalized.completedLessons,
      status: normalized.status,
      updatedAt: DateTime.now(),
    );
  }
}
