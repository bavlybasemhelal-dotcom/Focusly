import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../models/course_model.dart';
import '../services/course_tracker_service.dart';

/// Provider for CourseTrackerService singleton.
final courseTrackerServiceProvider = Provider<CourseTrackerService>((ref) {
  return CourseTrackerService();
});

/// Stream provider for all courses belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/courses`.
final coursesStreamProvider = StreamProvider<List<CourseModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(courseTrackerServiceProvider);
  return service.streamCourses(uid);
});

/// Derived provider: count of currently active courses.
final activeCoursesCountProvider = Provider<int>((ref) {
  final courses = ref.watch(coursesStreamProvider).value ?? [];
  return courses.where((c) => c.status == 'active').length;
});

/// Derived provider: count of completed courses.
final completedCoursesCountProvider = Provider<int>((ref) {
  final courses = ref.watch(coursesStreamProvider).value ?? [];
  return courses.where((c) => c.status == 'completed').length;
});

/// Derived provider: total lessons watched across all courses.
final totalLessonsWatchedProvider = Provider<int>((ref) {
  final courses = ref.watch(coursesStreamProvider).value ?? [];
  return courses.fold(0, (sum, c) => sum + c.completedLessons);
});
