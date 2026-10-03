import '../../../core/data/item_progress_service.dart';
import '../../../core/data/completion_intents.dart';
import '../../../core/data/firestore_paging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/calendar_clock.dart';
import '../../../core/data/completion_ledger.dart';
import '../helpers/streak_logic.dart';
import '../models/habit_model.dart';

class HabitHistoryService {
  HabitHistoryService(this.firestore);
  final FirebaseFirestore firestore;

  /// Dates are the source of truth; week rows are only a projection.
  Future<HabitModel> setCompleted({
    required String uid,
    required String habitId,
    required DateTime date,
    required bool completed,
    bool retrospective = false,
    DateTime? now,
  }) async {
    final today = calendarDay(now ?? DateTime.now());
    final selected = calendarDay(date);
    if (selected.isAfter(today) || (!retrospective && selected != today)) {
      throw ArgumentError(
        'Future dates are not allowed; past dates need an explicit retrospective entry',
      );
    }
    final user = firestore.collection('users').doc(uid);
    final habitRef = user.collection('habits').doc(habitId);
    final logRef = user
        .collection('habitLogs')
        .doc('${habitId}_${CompletionLedger.dateKey(selected)}');
    if (completed) {
      final before = await habitRef.get();
      if (before.exists) {
        await CompletionIntents.habit(
          uid,
          habitId,
          CompletionLedger.dateKey(selected),
          before.data()!,
        );
      }
    }
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(habitRef);
      if (!snapshot.exists) throw StateError('Habit no longer exists');
      final habit = HabitModel.fromMap(snapshot.data()!, habitId);
      if (!habit.weekdays.contains(selected.weekday)) {
        throw ArgumentError('This date is not scheduled for the habit');
      }
      if (selected.isBefore(calendarDay(habit.createdAt))) {
        throw ArgumentError('The habit did not exist on this date');
      }
      final history = await readFirestorePages(
        user.collection('habitLogs').where('habitId', isEqualTo: habitId),
      );
      final dates = <String>{
        for (final entry in history)
          if (entry.data()['completed'] == true) entry.data()['date'] as String,
      };
      final key = CompletionLedger.dateKey(selected);
      if (completed) {
        dates.add(key);
      } else {
        dates.remove(key);
      }
      final start = StreakLogic.getStartOfWeek(
        today,
        weekStartDay: habit.resetDay,
      );
      final days = [
        for (var index = 0; index < 7; index++)
          dates.contains(CompletionLedger.dateKey(calendarDay(start, index))),
      ];
      var cursor = dates.contains(CompletionLedger.dateKey(today))
          ? today
          : calendarDay(today, -1);
      var streak = 0;
      final oldest = dates.isEmpty
          ? today
          : DateTime.parse((dates.toList()..sort()).first);
      while (!cursor.isBefore(oldest)) {
        if (habit.weekdays.contains(cursor.weekday)) {
          if (!dates.contains(CompletionLedger.dateKey(cursor))) break;
          streak++;
        }
        cursor = calendarDay(cursor, -1);
      }
      final assignmentDone =
          habit.isGroupAssigned &&
          dates.any(
            (entry) =>
                !DateTime.parse(entry).isBefore(calendarDay(habit.createdAt)),
          );
      DocumentReference<Map<String, dynamic>>? mirror;
      if (habit.isGroupAssigned) {
        mirror = firestore
            .collection('groups')
            .doc(habit.assignedByGroupId)
            .collection('assignments')
            .doc(habit.groupAssignmentId)
            .collection('completions')
            .doc(uid);
        final previousMirror = await transaction.get(mirror);
        if (previousMirror.data()?['decision'] == 'rejected') {
          throw StateError('This assignment was rejected');
        }
      }
      final updated = habit.copyWith(
        days: days,
        streak: streak,
        baseStreak: 0,
        isCompleted: assignmentDone,
        lastResetDate: start,
      );
      transaction.set(logRef, {
        'habitId': habitId,
        'date': key,
        'completed': completed,
        'retrospective': retrospective,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(habitRef, {
        'days': days,
        'streak': streak,
        'baseStreak': 0,
        'isCompleted': assignmentDone,
        'lastResetDate': Timestamp.fromDate(start),
        'lastCompletedDate': dates.isEmpty
            ? null
            : (dates.toList()..sort()).last,
        'schemaVersion': 2,
      });
      if (mirror != null) {
        ItemProgressService.writeMirror(
          transaction,
          mirror,
          uid,
          habitId,
          'habits',
          updated.toMap(),
        );
      }
      return updated;
    });
  }

  Stream<List<Map<String, dynamic>>> history(String uid, {String? habitId}) {
    Query<Map<String, dynamic>> query = firestore
        .collection('users')
        .doc(uid)
        .collection('habitLogs');
    if (habitId != null) query = query.where('habitId', isEqualTo: habitId);
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
    );
  }
}
