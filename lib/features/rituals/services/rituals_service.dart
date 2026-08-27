import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../energy_mood/models/checkin_model.dart';
import '../../progress/constants/xp_constants.dart';
import '../../progress/services/progress_service.dart';
import '../../tasks/models/task_model.dart';
import '../models/gratitude_model.dart';
import '../models/ritual_model.dart';

/// Service handling Daily Rituals and multi-collection Shutdown transactions.
///
/// All collections are strictly isolated under: `users/{uid}/...`
class RitualsService {
  final FirebaseFirestore? _firestore;

  RitualsService({FirebaseFirestore? firestore}) : _firestore = firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? _ritualsCollection(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('rituals');
  }

  CollectionReference<Map<String, dynamic>>? _gratitudeCollection(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('gratitude');
  }

  CollectionReference<Map<String, dynamic>>? _checkinsCollection(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('checkins');
  }

  CollectionReference<Map<String, dynamic>>? _tasksCollection(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('tasks');
  }

  /// Streams today's ritual doc.
  Stream<RitualModel?> streamTodayRitual(String uid, String dateStr) {
    final col = _ritualsCollection(uid);
    if (col == null) return const Stream.empty();
    return col.doc(dateStr).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return RitualModel.fromMap(doc.data()!, doc.id);
    });
  }

  /// Directly fetches today's ritual doc once for non-stream startup checks.
  Future<RitualModel?> getTodayRitual(String uid, String dateStr) async {
    try {
      final col = _ritualsCollection(uid);
      if (col == null) return null;
      final doc = await col.doc(dateStr).get();
      if (!doc.exists || doc.data() == null) return null;
      return RitualModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('Error getting today ritual: $e');
      return null;
    }
  }

  /// Records that the morning intention prompt was shown/dismissed for [dateStr] in Firestore.
  Future<void> recordPromptShown(String uid, String dateStr) async {
    try {
      final col = _ritualsCollection(uid);
      if (col == null) return;
      final docRef = col.doc(dateStr);
      await docRef.set(
        {
          'date': dateStr,
          'promptShown': true,
          'lastPromptDate': dateStr,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Error recording prompt shown in Firestore: $e');
    }
  }

  /// Streams all rituals ordered by date descending.
  Stream<List<RitualModel>> streamRituals(String uid) {
    final col = _ritualsCollection(uid);
    if (col == null) return const Stream.empty();
    return col
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RitualModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Saves or updates the morning intention for [dateStr].
  Future<bool> setMorningIntention({
    required String uid,
    required String dateStr,
    required String intention,
  }) async {
    try {
      final col = _ritualsCollection(uid);
      if (col == null) return false;
      final docRef = col.doc(dateStr);
      final now = DateTime.now();

      await docRef.set(
        {
          'date': dateStr,
          'intention': intention.trim(),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      return true;
    } catch (e) {
      debugPrint('Error saving morning intention: $e');
      return false;
    }
  }

  /// Moves unfinished standard tasks to tomorrow's date.
  Future<int> postponeUnfinishedTasksToTomorrow({
    required String uid,
    required List<TaskModel> tasks,
  }) async {
    try {
      final db = _db;
      final taskCol = _tasksCollection(uid);
      if (db == null || taskCol == null) return 0;

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);

      // Filter: unfinished, standard tasks (not GTD special lists)
      final tasksToMove = tasks.where((t) => !t.done && t.listType == null).toList();
      if (tasksToMove.isEmpty) return 0;

      final batch = db.batch();
      for (final task in tasksToMove) {
        final docRef = taskCol.doc(task.id);
        batch.update(docRef, {
          'date': Timestamp.fromDate(tomorrow),
        });
      }

      await batch.commit();
      return tasksToMove.length;
    } catch (e) {
      debugPrint('Error postponing tasks: $e');
      return 0;
    }
  }

  /// Completes the multi-step Shutdown Ritual with multi-collection writes.
  ///
  /// Writes performed:
  /// 1. Upsert `users/{uid}/gratitude/{dateStr}` with 3 gratitude items.
  /// 2. Upsert `users/{uid}/checkins/{dateStr}` merging Energy, Mood, and Gratitude note (preserving water/sleep).
  /// 3. Create tomorrow's tasks in `users/{uid}/tasks`.
  /// 4. Save `users/{uid}/rituals/{dateStr}` with completed shutdown data.
  /// 5. Award +30 XP.
  Future<bool> finishShutdownRitual({
    required String uid,
    required String dateStr,
    required int energyLevel,
    required String mood,
    required String gratitude1,
    required String gratitude2,
    required String gratitude3,
    String? lesson,
    required List<String> tomorrowTaskTitles,
    WidgetRef? ref,
  }) async {
    try {
      final gratCol = _gratitudeCollection(uid);
      final checkinCol = _checkinsCollection(uid);
      final taskCol = _tasksCollection(uid);
      final ritualCol = _ritualsCollection(uid);
      if (gratCol == null || checkinCol == null || taskCol == null || ritualCol == null) {
        return false;
      }

      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final combinedGratitude = '$gratitude1 • $gratitude2 • $gratitude3';

      // 1. Gratitude Log Upsert
      // TODO: Future Gratitude Log feature builds directly on this collection.
      final gratitudeDoc = GratitudeModel(
        id: dateStr,
        date: now,
        item1: gratitude1.trim(),
        item2: gratitude2.trim(),
        item3: gratitude3.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await gratCol.doc(dateStr).set(
            gratitudeDoc.toMap(),
            SetOptions(merge: true),
          );

      // 2. Energy & Mood Check-in Merge (Preserving existing water/sleep)
      final checkinDocRef = checkinCol.doc(dateStr);
      final existingCheckinDoc = await checkinDocRef.get();
      CheckinModel? existingCheckin;
      if (existingCheckinDoc.exists && existingCheckinDoc.data() != null) {
        existingCheckin = CheckinModel.fromMap(existingCheckinDoc.data()!, dateStr);
      }

      final mergedCheckin = CheckinModel(
        date: dateStr,
        energy: energyLevel,
        mood: mood,
        water: existingCheckin?.water ?? 0,
        sleep: existingCheckin?.sleep ?? 0.0,
        sleepTime: existingCheckin?.sleepTime,
        wakeTime: existingCheckin?.wakeTime,
        sleepXpAwarded: existingCheckin?.sleepXpAwarded ?? false,
        waterXpGlassesAwarded: existingCheckin?.waterXpGlassesAwarded ?? 0,
        note: combinedGratitude,
        createdAt: existingCheckin?.createdAt ?? now,
        updatedAt: now,
      );
      await checkinDocRef.set(mergedCheckin.toMap(), SetOptions(merge: true));

      // 3. Create Tomorrow's Tasks
      final validTomorrowTasks = tomorrowTaskTitles
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      for (final title in validTomorrowTasks) {
        final taskDocRef = taskCol.doc();
        final newTask = TaskModel(
          id: taskDocRef.id,
          title: title,
          categoryId: 'work',
          priority: TaskPriority.medium,
          date: tomorrow,
          done: false,
          createdAt: now,
        );
        await taskDocRef.set(newTask.toMap());
      }

      // 4. Save Shutdown Data on Ritual document
      final shutdownData = ShutdownData(
        completed: true,
        gratitudeText: combinedGratitude,
        tomorrowTasks: validTomorrowTasks,
        lesson: (lesson != null && lesson.trim().isNotEmpty) ? lesson.trim() : null,
        completedAt: now,
      );

      await ritualCol.doc(dateStr).set(
        {
          'date': dateStr,
          'shutdown': shutdownData.toMap(),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );

      // 5. XP hook: Award +30 XP for completing evening shutdown ritual
      if (ref != null) {
        await ProgressService().awardXp(
          XpConstants.eveningShutdown,
          source: 'Evening shutdown ritual completed',
          sourceType: 'rituals',
          ref: ref,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error finishing shutdown ritual: $e');
      return false;
    }
  }
}
