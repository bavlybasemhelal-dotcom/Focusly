import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../helpers/course_status_helper.dart';
import '../models/course_model.dart';

/// Service managing Firestore operations for the Course Tracker feature.
///
/// Documents are isolated per user under `users/{uid}/courses/{courseId}`.
class CourseTrackerService {
  final FirebaseFirestore _firestore;

  CourseTrackerService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _coursesCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('courses');
  }

  /// Streams all courses for [uid] ordered by updatedAt descending.
  Stream<List<CourseModel>> streamCourses(String uid) {
    return _coursesCollection(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => CourseModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new course.
  Future<String?> addCourse({
    required String uid,
    required String title,
    String? platform,
    required int totalLessons,
    int completedLessons = 0,
    String status = 'active',
    bool certificate = false,
    String? note,
    BuildContext? context,
  }) async {
    try {
      final docRef = _coursesCollection(uid).doc();
      final now = DateTime.now();

      final normalized = CourseStatusHelper.normalizeCourseProgress(
        totalLessons: totalLessons,
        completedLessons: completedLessons,
        manualStatus: status,
      );

      final course = CourseModel(
        id: docRef.id,
        title: title.trim(),
        platform: (platform != null && platform.trim().isNotEmpty)
            ? platform.trim()
            : null,
        totalLessons: normalized.totalLessons,
        completedLessons: normalized.completedLessons,
        status: normalized.status,
        certificate: certificate,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(course.toMap());

      if (normalized.isNewlyCompleted && context != null && context.mounted) {
        _triggerCourseCompletedCelebration(course.title, context);
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding course: $e');
      return null;
    }
  }

  /// Updates an existing course.
  Future<bool> updateCourse({
    required String uid,
    required CourseModel currentCourse,
    required String newTitle,
    String? newPlatform,
    required int newTotalLessons,
    required int newCompletedLessons,
    required String newStatus,
    required bool newCertificate,
    String? newNote,
    BuildContext? context,
  }) async {
    try {
      if (newTitle.trim().isEmpty ||
          newTotalLessons < 1 ||
          newTotalLessons > 100000 ||
          newCompletedLessons < 0 ||
          newCompletedLessons > newTotalLessons) {
        throw ArgumentError('Invalid course');
      }
      final docRef = _coursesCollection(uid).doc(currentCourse.id);
      final updated = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw StateError('Course no longer exists');
        final fresh = CourseModel.fromMap(snapshot.data()!, currentCourse.id);
        final changedProgress =
            newCompletedLessons != currentCourse.completedLessons ||
            newStatus != currentCourse.status;
        if (changedProgress &&
            (fresh.completedLessons != currentCourse.completedLessons ||
                fresh.status != currentCourse.status)) {
          throw StateError('Course progress changed. Reopen the form.');
        }
        final normalized = CourseStatusHelper.normalizeCourseProgress(
          totalLessons: newTotalLessons,
          completedLessons: changedProgress
              ? newCompletedLessons
              : fresh.completedLessons,
          manualStatus: changedProgress ? newStatus : fresh.status,
          previousStatus: fresh.status,
        );
        if (newTotalLessons < fresh.completedLessons) {
          throw StateError('Cannot truncate completed lessons');
        }
        final result = fresh.copyWith(
          title: newTitle == currentCourse.title
              ? fresh.title
              : newTitle.trim(),
          platform: newPlatform == currentCourse.platform
              ? fresh.platform
              : newPlatform,
          clearPlatform:
              newPlatform != currentCourse.platform &&
              (newPlatform == null || newPlatform.trim().isEmpty),
          totalLessons: normalized.totalLessons,
          completedLessons: normalized.completedLessons,
          status: normalized.status,
          certificate: newCertificate == currentCourse.certificate
              ? fresh.certificate
              : newCertificate,
          note: newNote == currentCourse.note ? fresh.note : newNote,
          clearNote:
              newNote != currentCourse.note &&
              (newNote == null || newNote.trim().isEmpty),
          updatedAt: DateTime.now(),
        );
        transaction.update(docRef, result.toMap()..remove('createdAt'));
        return result;
      });
      if (currentCourse.status != 'completed' &&
          updated.status == 'completed' &&
          context != null &&
          context.mounted) {
        _triggerCourseCompletedCelebration(updated.title, context);
      }

      return true;
    } catch (e) {
      debugPrint('Error updating course: $e');
      return false;
    }
  }

  /// Quick stepper adjustment (+1 or -1 lesson) on a course card.
  Future<bool> adjustLessonsStepper({
    required String uid,
    required CourseModel course,
    required int delta,
    BuildContext? context,
  }) async {
    try {
      if (delta.abs() != 1) throw ArgumentError('Invalid lesson adjustment');
      final docRef = _coursesCollection(uid).doc(course.id);
      var wasCompleted = false;
      final updated = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw StateError('Course no longer exists');
        final current = CourseModel.fromMap(snapshot.data()!, course.id);
        wasCompleted = current.status == 'completed';
        final changed = CourseStatusHelper.adjustCompletedLessons(
          current,
          delta,
        );
        transaction.update(docRef, {
          'completedLessons': changed.completedLessons,
          'status': changed.status,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return changed;
      });

      // Trigger celebratory toast if course newly completed
      if (!wasCompleted &&
          updated.status == 'completed' &&
          context != null &&
          context.mounted) {
        _triggerCourseCompletedCelebration(updated.title, context);
      }

      return true;
    } catch (e) {
      debugPrint('Error adjusting lessons stepper: $e');
      return false;
    }
  }

  /// Deletes a course.
  Future<bool> deleteCourse({
    required String uid,
    required String courseId,
  }) async {
    try {
      await _coursesCollection(uid).doc(courseId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting course: $e');
      return false;
    }
  }

  void _triggerCourseCompletedCelebration(
    String courseTitle,
    BuildContext context,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'course_completed_celebration',
            args: {'title': courseTitle},
          ),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
