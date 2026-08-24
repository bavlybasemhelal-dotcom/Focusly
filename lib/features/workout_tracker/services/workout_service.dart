import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/workout_model.dart';

/// Service managing Firestore operations for the Workout Tracker feature.
///
/// Documents are isolated per user under `users/{uid}/workouts/{workoutId}`.
class WorkoutService {
  final FirebaseFirestore _firestore;

  WorkoutService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _workoutsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('workouts');
  }

  /// Streams all workouts for [uid] ordered by date descending.
  Stream<List<WorkoutModel>> streamWorkouts(String uid) {
    return _workoutsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => WorkoutModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new workout entry.
  Future<String?> addWorkout({
    required String uid,
    required String type,
    required int durationMin,
    int calories = 0,
    required DateTime date,
    String? note,
  }) async {
    try {
      final docRef = _workoutsCollection(uid).doc();
      final now = DateTime.now();

      final workout = WorkoutModel(
        id: docRef.id,
        type: type.trim(),
        durationMin: durationMin > 0 ? durationMin : 1,
        calories: calories >= 0 ? calories : 0,
        date: date,
        note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(workout.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding workout: $e');
      return null;
    }
  }

  /// Updates an existing workout entry.
  Future<bool> updateWorkout({
    required String uid,
    required WorkoutModel currentWorkout,
    required String newType,
    required int newDurationMin,
    required int newCalories,
    required DateTime newDate,
    String? newNote,
  }) async {
    try {
      final now = DateTime.now();
      final updated = currentWorkout.copyWith(
        type: newType.trim(),
        durationMin: newDurationMin > 0 ? newDurationMin : 1,
        calories: newCalories >= 0 ? newCalories : 0,
        date: newDate,
        note: (newNote != null && newNote.trim().isNotEmpty) ? newNote.trim() : null,
        clearNote: newNote == null || newNote.trim().isEmpty,
        updatedAt: now,
      );

      await _workoutsCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating workout: $e');
      return false;
    }
  }

  /// Deletes a workout entry.
  Future<bool> deleteWorkout({
    required String uid,
    required String workoutId,
  }) async {
    try {
      await _workoutsCollection(uid).doc(workoutId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting workout: $e');
      return false;
    }
  }
}
