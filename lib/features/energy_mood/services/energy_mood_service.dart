import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';
import '../models/checkin_model.dart';

/// Service managing Firestore operations for the Energy & Mood daily check-in feature.
///
/// Fully isolated per user under `users/{uid}/checkins/{dateString}`.
class EnergyMoodService {
  final FirebaseFirestore _firestore;

  EnergyMoodService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Helper returning the formatted date string "YYYY-MM-DD" for any given DateTime.
  static String formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Helper returning today's date string "YYYY-MM-DD".
  static String get todayString => formatDate(DateTime.now());

  /// Returns collection reference scoped to the user's isolated subcollection.
  CollectionReference<Map<String, dynamic>> _checkinsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('checkins');
  }

  /// Returns real-time stream of today's check-in for the given user.
  Stream<CheckinModel?> streamTodayCheckin(String uid) {
    final today = todayString;
    return _checkinsCollection(uid).doc(today).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CheckinModel.fromMap(snap.data()!, snap.id);
    });
  }

  /// Returns real-time stream of a check-in for any given date string "YYYY-MM-DD".
  Stream<CheckinModel?> streamCheckinForDate(String uid, String dateStr) {
    return _checkinsCollection(uid).doc(dateStr).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return CheckinModel.fromMap(snap.data()!, snap.id);
    });
  }

  /// Returns real-time stream of all past check-ins ordered by date descending.
  Stream<List<CheckinModel>> streamCheckinsHistory(String uid, {int limit = 60}) {
    return _checkinsCollection(uid)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => CheckinModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  /// Fetches a check-in document once.
  Future<CheckinModel?> getCheckin(String uid, String dateStr) async {
    try {
      final doc = await _checkinsCollection(uid).doc(dateStr).get();
      if (!doc.exists || doc.data() == null) return null;
      return CheckinModel.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates energy, mood, and note for a specific date.
  ///
  /// Awards +15 XP if this is the first time checking in on this date.
  Future<bool> saveCheckin({
    required String uid,
    required String date,
    required int energy,
    required String mood,
    String? note,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final docRef = _checkinsCollection(uid).doc(date);
      final existingDoc = await docRef.get();
      final now = DateTime.now();

      final isNewCheckin = !existingDoc.exists;

      if (isNewCheckin) {
        final newModel = CheckinModel(
          date: date,
          energy: energy,
          mood: mood,
          note: note,
          water: 0,
          sleep: 0.0,
          createdAt: now,
          updatedAt: now,
        );
        await docRef.set(newModel.toMap());

        // XP hook: Award +15 XP for completing a daily check-in
        await ProgressService().awardXp(
          XpConstants.dailyCheckin,
          source: 'Daily check-in completed',
          sourceType: 'checkin',
          context: context,
          ref: ref,
        );
      } else {
        final data = existingDoc.data()!;
        final existingModel = CheckinModel.fromMap(data, date);
        final updatedModel = existingModel.copyWith(
          energy: energy,
          mood: mood,
          note: note,
          clearNote: note == null || note.trim().isEmpty,
          updatedAt: now,
        );
        await docRef.set(updatedModel.toMap(), SetOptions(merge: true));
      }
      return true;
    } catch (e) {
      debugPrint('Error saving check-in: $e');
      return false;
    }
  }

  /// Updates water intake count for a given date.
  ///
  /// Awards +5 XP per glass logged, capped at double the daily water target (e.g. max 16 glasses).
  Future<bool> updateWater({
    required String uid,
    required String date,
    required int newWaterCount,
    int dailyTarget = 8,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final docRef = _checkinsCollection(uid).doc(date);
      final existingDoc = await docRef.get();
      final now = DateTime.now();

      CheckinModel current;
      if (existingDoc.exists && existingDoc.data() != null) {
        current = CheckinModel.fromMap(existingDoc.data()!, date);
      } else {
        current = CheckinModel(
          date: date,
          energy: 3,
          mood: '🙂',
          water: 0,
          sleep: 0.0,
          createdAt: now,
          updatedAt: now,
        );
      }

      // XP calculation capped at 2 * dailyTarget
      final maxEligibleGlasses = 2 * dailyTarget;
      final currentAwarded = current.waterXpGlassesAwarded;
      int newlyEligibleGlasses = 0;

      if (newWaterCount > currentAwarded) {
        final cappedCount = min(newWaterCount, maxEligibleGlasses);
        newlyEligibleGlasses = max(0, cappedCount - currentAwarded);
      }

      final updatedAwarded = currentAwarded + newlyEligibleGlasses;

      final updated = current.copyWith(
        water: max(0, newWaterCount),
        waterXpGlassesAwarded: updatedAwarded,
        updatedAt: now,
      );

      await docRef.set(updated.toMap(), SetOptions(merge: true));

      // XP hook: Award +5 XP per newly logged water glass up to the cap
      if (newlyEligibleGlasses > 0) {
        await ProgressService().awardXp(
          newlyEligibleGlasses * XpConstants.waterPerGlass,
          source: 'Logged $newlyEligibleGlasses glass${newlyEligibleGlasses > 1 ? "es" : ""} of water',
          sourceType: 'water',
          context: context,
          ref: ref,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating water: $e');
      return false;
    }
  }

  /// Updates sleep time, wake time, and computed sleep hours for a given date.
  ///
  /// Awards +15 XP once per day when sleep is recorded.
  Future<bool> updateSleep({
    required String uid,
    required String date,
    required TimeOfDay sleepTime,
    required TimeOfDay wakeTime,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final docRef = _checkinsCollection(uid).doc(date);
      final existingDoc = await docRef.get();
      final now = DateTime.now();

      CheckinModel current;
      if (existingDoc.exists && existingDoc.data() != null) {
        current = CheckinModel.fromMap(existingDoc.data()!, date);
      } else {
        current = CheckinModel(
          date: date,
          energy: 3,
          mood: '🙂',
          water: 0,
          sleep: 0.0,
          createdAt: now,
          updatedAt: now,
        );
      }

      final durationHours = computeSleepDurationFromTime(sleepTime, wakeTime);
      final sleepTimeStr = formatTimeOfDay(sleepTime);
      final wakeTimeStr = formatTimeOfDay(wakeTime);

      final shouldAwardXp = !current.sleepXpAwarded;

      final updated = current.copyWith(
        sleep: durationHours,
        sleepTime: sleepTimeStr,
        wakeTime: wakeTimeStr,
        sleepXpAwarded: true,
        updatedAt: now,
      );

      await docRef.set(updated.toMap(), SetOptions(merge: true));

      // XP hook: Award +15 XP once per day for logging sleep
      if (shouldAwardXp) {
        await ProgressService().awardXp(
          XpConstants.sleepLogged,
          source: 'Logged sleep ($durationHours hrs)',
          sourceType: 'sleep',
          context: context,
          ref: ref,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error updating sleep: $e');
      return false;
    }
  }
}
