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
  Stream<List<CheckinModel>> streamCheckinsHistory(
    String uid, {
    int limit = 60,
  }) {
    return _checkinsCollection(
      uid,
    ).orderBy('date', descending: true).limit(limit).snapshots().map((snap) {
      return snap.docs
          .map((doc) => CheckinModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<CheckinModel>> streamYearCheckins(String uid, int year) =>
      _checkinsCollection(uid)
          .where('date', isGreaterThanOrEqualTo: '$year-01-01')
          .where('date', isLessThan: '${year + 1}-01-01')
          .orderBy('date')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => CheckinModel.fromMap(doc.data(), doc.id))
                .toList(),
          );

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
  Future<void> _patchDay(
    String uid,
    String date,
    Map<String, dynamic> changes,
  ) async {
    if (uid.isEmpty || DateTime.tryParse(date) == null) {
      throw ArgumentError('Invalid account or date');
    }
    final document = _checkinsCollection(uid).doc(date);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      transaction.set(document, {
        if (!existing.exists) ...{
          'date': date,
          'energy': 0,
          'mood': '🙂',
          'water': 0,
          'sleep': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        },
        ...changes,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<bool> saveCheckin({
    required String uid,
    required String date,
    required int energy,
    required String mood,
    String? note,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    if (energy < 1 || energy > 5 || mood.trim().isEmpty) return false;
    try {
      await _patchDay(uid, date, {
        'energy': energy,
        'mood': mood,
        'note': note?.trim(),
      });
      await ProgressService(firestore: _firestore).awardXp(
        XpConstants.dailyCheckin,
        uid: uid,
        eventId: 'checkin_$date',
        sourceId: date,
        source: 'Daily check-in completed',
        sourceType: 'checkin',
        context: context != null && context.mounted ? context : null,
        ref: ref,
      );
      return true;
    } catch (error) {
      debugPrint('Check-in save failed: $error');
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
    if (newWaterCount < 0 || newWaterCount > 100 || dailyTarget <= 0) {
      return false;
    }
    try {
      await _patchDay(uid, date, {'water': newWaterCount});
      final eligible = min(newWaterCount, min(2 * dailyTarget, 16));
      // Retry all eligible stable keys: an interrupted reward is never lost.
      for (var glass = 1; glass <= eligible; glass++) {
        await ProgressService(firestore: _firestore).awardXp(
          XpConstants.waterPerGlass,
          uid: uid,
          eventId: 'water_${date}_$glass',
          sourceId: date,
          source: 'Logged water glass $glass',
          sourceType: 'water',
          context: context != null && context.mounted ? context : null,
          ref: ref,
        );
      }
      await _patchDay(uid, date, {'waterXpGlassesAwarded': eligible});
      return true;
    } catch (error) {
      debugPrint('Water save failed: $error');
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
      final hours = computeSleepDurationFromTime(sleepTime, wakeTime);
      await _patchDay(uid, date, {
        'sleep': hours,
        'sleepTime': formatTimeOfDay(sleepTime),
        'wakeTime': formatTimeOfDay(wakeTime),
      });
      if (hours > 0) {
        await ProgressService(firestore: _firestore).awardXp(
          XpConstants.sleepLogged,
          uid: uid,
          eventId: 'sleep_$date',
          sourceId: date,
          source: 'Logged sleep ($hours hrs)',
          sourceType: 'sleep',
          context: context != null && context.mounted ? context : null,
          ref: ref,
        );
        await _patchDay(uid, date, {'sleepXpAwarded': true});
      }
      return true;
    } catch (error) {
      debugPrint('Sleep save failed: $error');
      return false;
    }
  }
}
