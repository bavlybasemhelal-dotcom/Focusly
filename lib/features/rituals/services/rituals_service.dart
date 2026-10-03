import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      await docRef.set({
        'date': dateStr,
        'promptShown': true,
        'lastPromptDate': dateStr,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording prompt shown in Firestore: $e');
    }
  }

  /// Streams all rituals ordered by date descending.
  Stream<List<RitualModel>> streamRituals(String uid) {
    final col = _ritualsCollection(uid);
    if (col == null) return const Stream.empty();
    return col.orderBy('date', descending: true).snapshots().map((snapshot) {
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

      await docRef.set({
        'date': dateStr,
        'intention': intention.trim(),
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
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
      final tasksToMove = tasks
          .where((t) => !t.done && t.listType == null)
          .toList();
      if (tasksToMove.isEmpty) return 0;

      final batch = db.batch();
      for (final task in tasksToMove) {
        final docRef = taskCol.doc(task.id);
        batch.update(docRef, {'date': Timestamp.fromDate(tomorrow)});
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
    if (uid.isEmpty ||
        DateTime.tryParse(dateStr) == null ||
        energyLevel < 1 ||
        energyLevel > 5 ||
        tomorrowTaskTitles.length > 3) {
      return false;
    }
    try {
      final database = _db;
      final rituals = _ritualsCollection(uid);
      final tasks = _tasksCollection(uid);
      final gratitude = _gratitudeCollection(uid);
      final checkins = _checkinsCollection(uid);
      if (database == null ||
          rituals == null ||
          tasks == null ||
          gratitude == null ||
          checkins == null) {
        return false;
      }
      final now = DateTime.now();
      final day = DateTime.parse(dateStr);
      final tomorrow = DateTime(day.year, day.month, day.day + 1);
      final titles = tomorrowTaskTitles
          .map((title) => title.trim())
          .where((title) => title.isNotEmpty)
          .toList();
      final combined = '$gratitude1 • $gratitude2 • $gratitude3';
      await database.runTransaction((transaction) async {
        final existing = await transaction.get(rituals.doc(dateStr));
        if ((existing.data()?['shutdown'] as Map?)?['completed'] == true) {
          return;
        }
        transaction.set(
          gratitude.doc(dateStr),
          GratitudeModel(
            id: dateStr,
            date: day,
            item1: gratitude1.trim(),
            item2: gratitude2.trim(),
            item3: gratitude3.trim(),
            createdAt: now,
            updatedAt: now,
          ).toMap(),
        );
        transaction.set(checkins.doc(dateStr), {
          'date': dateStr,
          'energy': energyLevel,
          'mood': mood,
          'note': combined,
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
        for (var index = 0; index < titles.length; index++) {
          final document = tasks.doc('ritual_${dateStr}_$index');
          transaction.set(
            document,
            TaskModel(
              id: document.id,
              title: titles[index],
              categoryId: 'work',
              priority: TaskPriority.medium,
              date: tomorrow,
              done: false,
              createdAt: now,
            ).toMap(),
          );
        }
        final shutdown = ShutdownData(
          completed: true,
          gratitudeText: combined,
          tomorrowTasks: titles,
          lesson: lesson?.trim(),
          completedAt: now,
        );
        transaction.set(rituals.doc(dateStr), {
          'date': dateStr,
          'shutdown': shutdown.toMap(),
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));
      });
      await ProgressService(firestore: database).awardXp(
        XpConstants.eveningShutdown,
        uid: uid,
        sourceId: dateStr,
        eventId: 'rituals_$dateStr',
        source: 'Evening shutdown ritual completed',
        sourceType: 'rituals',
        ref: ref,
      );
      return true;
    } catch (error) {
      debugPrint('Shutdown ritual save failed: $error');
      return false;
    }
  }
}
