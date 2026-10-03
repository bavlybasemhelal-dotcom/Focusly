import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusly/core/data/completion_ledger.dart';
import 'package:focusly/core/data/item_progress_service.dart';
import 'package:focusly/core/data/pending_operations.dart';
import 'package:focusly/core/notifications/managed_notification_sender.dart';
import 'package:focusly/core/notifications/platform_senders/platform_notification_sender.dart';
import 'package:focusly/features/productivity/services/productivity_service.dart';
import 'package:focusly/features/productivity/services/trash_service.dart';
import 'package:focusly/features/productivity/services/backup_service.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/habits/services/habit_history_service.dart';

class RecordingSender implements PlatformNotificationSender {
  final scheduled = <int, Map<String, dynamic>>{};
  final cancelled = <int>[];
  Future<void> Function()? onSchedule;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> requestPermissions() async => true;
  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    scheduled[id] = {'date': scheduledDate, 'payload': payload};
    await onSchedule?.call();
  }

  @override
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {}
  @override
  Future<void> cancelNotification(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> cancelAllNotifications() async => scheduled.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  TaskModel task(String id, DateTime date, {bool done = false}) => TaskModel(
    id: id,
    title: 'Task $id',
    categoryId: 'work',
    date: date,
    createdAt: date,
    done: done,
  );

  test(
    'dependency cycles and unfinished prerequisites cannot complete a task',
    () async {
      final db = FakeFirebaseFirestore(),
          service = ProductivityService(FakeFirebaseFirestore());
      final tools = ProductivityService(db);
      for (final id in ['a', 'b']) {
        await db
            .doc('users/u/tasks/$id')
            .set(task(id, DateTime(2026, 10, 3)).toMap());
      }
      await tools.linkTask(uid: 'u', taskId: 'a', dependencies: ['b']);
      await expectLater(
        tools.linkTask(uid: 'u', taskId: 'b', dependencies: ['a']),
        throwsStateError,
      );
      await expectLater(
        ItemProgressService(db).task(uid: 'u', id: 'a', done: true),
        throwsStateError,
      );
      await ItemProgressService(db).task(uid: 'u', id: 'b', done: true);
      await ItemProgressService(db).task(uid: 'u', id: 'a', done: true);
      expect((await db.doc('users/u/tasks/a').get()).data()!['done'], true);
      expect(service.firestore, isNotNull);
    },
  );
  test(
    'linked milestones require all linked tasks and preserve a manual override',
    () async {
      final db = FakeFirebaseFirestore();
      final tools = ProductivityService(db);
      await db.doc('users/u/goals/g').set({
        'milestones': [
          {'title': 'Release', 'done': false},
        ],
        'progress': 0,
      });
      for (final id in ['a', 'b']) {
        await db
            .doc('users/u/tasks/$id')
            .set(task(id, DateTime(2026, 10, 3)).toMap());
        await tools.linkTask(
          uid: 'u',
          taskId: id,
          dependencies: [],
          goalId: 'g',
          milestoneTitle: 'Release',
        );
      }
      await ItemProgressService(db).task(uid: 'u', id: 'a', done: true);
      expect((await db.doc('users/u/goals/g').get()).data()!['progress'], 0);
      await ItemProgressService(db).task(uid: 'u', id: 'b', done: true);
      expect((await db.doc('users/u/goals/g').get()).data()!['progress'], 100);
      await db.doc('users/u/goals/g').update({
        'manualMilestones': ['Release'],
      });
      await ItemProgressService(db).task(uid: 'u', id: 'a', done: false);
      expect((await db.doc('users/u/goals/g').get()).data()!['progress'], 100);
    },
  );
  test(
    'recurrence reuses its original occurrence and retry does not duplicate it',
    () async {
      final db = FakeFirebaseFirestore();
      final tools = ProductivityService(db);
      final date = DateTime(2026, 10, 3);
      final original = task('a', date);
      await db.doc('users/u/tasks/a').set(original.toMap());
      await tools.saveRecurrence('u', original, 'daily');
      await tools.materialize('u', date);
      await tools.materialize('u', date);
      expect((await db.collection('users/u/tasks').get()).docs, hasLength(2));
      await tools.skipOccurrence('u', 'a');
      await tools.materialize('u', date);
      expect((await db.collection('users/u/tasks').get()).docs, hasLength(1));
    },
  );
  test(
    'monthly recurrence uses the last real day for a day-31 template',
    () async {
      final db = FakeFirebaseFirestore(), date = DateTime(2026, 1, 31);
      final tools = ProductivityService(db);
      final original = task('a', date);
      await db.doc('users/u/tasks/a').set(original.toMap());
      await tools.saveRecurrence('u', original, 'monthly');
      await tools.materialize('u', DateTime(2026, 2, 28));
      final docs = (await db.collection('users/u/tasks').get()).docs;
      expect(
        docs.where((doc) => doc.data()['occurrenceDate'] == '2026-02-28'),
        hasLength(1),
      );
    },
  );
  test('template requests create one batch even after three retries', () async {
    final db = FakeFirebaseFirestore();
    final tools = ProductivityService(db);
    await tools.saveTemplate('u', 'Morning', [
      task('a', DateTime(2026, 10, 3)),
      task('b', DateTime(2026, 10, 3)),
    ]);
    final id =
        (await db.collection('users/u/taskTemplates').get()).docs.single.id;
    for (var i = 0; i < 3; i++) {
      await tools.useTemplate('u', id, 'intent', DateTime(2026, 10, 3));
    }
    expect((await db.collection('users/u/tasks').get()).docs, hasLength(2));
  });
  test(
    'trash restores an original ID without restoring a second reward',
    () async {
      final db = FakeFirebaseFirestore(), date = DateTime(2026, 10, 3);
      await db.doc('users/u/tasks/a').set(task('a', date, done: true).toMap());
      final ledger = CompletionLedger(db);
      expect(
        await ledger.award(
          uid: 'u',
          eventId: 'task_a',
          sourceId: 'a',
          sourceType: 'task',
          amount: 10,
          label: 'Task',
        ),
        true,
      );
      final bin = TrashService(db);
      final key = await bin.move('u', 'tasks', 'a');
      await bin.restore('u', key);
      expect(
        await ledger.award(
          uid: 'u',
          eventId: 'task_a',
          sourceId: 'a',
          sourceType: 'task',
          amount: 10,
          label: 'Task',
        ),
        false,
      );
      expect((await db.doc('users/u/stats/progress').get()).data()!['xp'], 10);
      await db.doc('users/u/tasks/a').update({'locked': true});
      await expectLater(bin.move('u', 'tasks', 'a'), throwsStateError);
    },
  );
  test(
    'backup previews exclude rewards, reject another UID and prevent duplicate IDs',
    () async {
      final db = FakeFirebaseFirestore();
      await db
          .doc('users/u/tasks/a')
          .set(task('a', DateTime(2026, 10, 3)).toMap());
      await db.doc('users/u/completionEvents/reward').set({'amount': 10});
      final service = BackupService(db);
      final backup = await service.export('u');
      final preview = BackupService.preview(backup, 'u');
      expect(preview.duplicates, 0);
      expect(await service.import('u', preview), 0);
      expect(preview.skipped, 1);
      expect(() => BackupService.preview(backup, 'v'), throwsFormatException);
      final encoded = BackupService.encode(
        Timestamp.fromDate(DateTime.utc(2026, 10, 3)),
      );
      expect(
        (BackupService.decode(encoded) as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 10, 3),
      );
      expect(jsonDecode(backup)['schemaVersion'], 1);
    },
  );
  test('CSV quotes user text and neutralizes spreadsheet formulas', () {
    final csv = BackupService.csv(
      [
        {'title': '=HYPERLINK("bad")', 'notes': 'a,b\ntext'},
      ],
      ['title', 'notes'],
    );
    expect(csv, contains("'=HYPERLINK"));
    expect(csv, contains('"a,b\ntext"'));
  });
  test('pending jobs are idempotent and isolated by account', () async {
    await PendingOperations.enqueue('a', 'reward', 't', {'amount': 10});
    await PendingOperations.enqueue('a', 'reward', 't', {'amount': 50});
    await PendingOperations.enqueue('b', 'reward', 't', {'amount': 10});
    expect((await PendingOperations.list('a')).single['payload'], {
      'amount': 10,
    });
    await PendingOperations.clearAccount('a');
    expect(await PendingOperations.list('a'), isEmpty);
    expect(await PendingOperations.list('b'), hasLength(1));
  });
  test(
    'quiet hours cross midnight; turning reminders off and on keeps one intent',
    () async {
      final native = RecordingSender();
      final sender = ManagedNotificationSender(
        native,
        accountProvider: () => 'u',
      );
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await sender.scheduleNotification(
        id: 7,
        title: 'Reminder',
        body: 'Task',
        scheduledDate: tomorrow,
        payload: 'task:a',
        channelId: 'task_reminders',
      );
      await sender.updateSettings('u', {'enabled': false});
      expect(native.scheduled, isEmpty);
      expect((await sender.pending()).single['status'], 'paused');
      await sender.updateSettings('u', {'enabled': true});
      expect(native.scheduled, hasLength(1));
      expect(native.scheduled.values.single['payload'], 'account=u|task:a');
      expect(
        ManagedNotificationSender.applyQuietHours(DateTime(2026, 10, 3, 23), {
          'quietEnabled': true,
          'quietStart': 22,
          'quietEnd': 7,
        }),
        DateTime(2026, 10, 4, 7),
      );
      await sender.snooze(7, const Duration(minutes: 10));
      expect(native.scheduled, hasLength(1));
    },
  );
  test(
    'account changes during native scheduling cancel the old private alert',
    () async {
      var uid = 'a';
      final native = RecordingSender()
        ..onSchedule = (() async {
          uid = 'b';
        });
      final sender = ManagedNotificationSender(
        native,
        accountProvider: () => uid,
      );
      await sender.scheduleNotification(
        id: 1,
        title: 'A private task',
        body: 'Private',
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(native.scheduled, isEmpty);
      expect(await sender.pending(account: 'b'), isEmpty);
    },
  );
  test(
    'custom habit weekdays count scheduled dates and reject an off-day',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u/habits/h').set({
        'title': 'Custom',
        'days': List.filled(7, false),
        'weekdays': [1, 3, 5],
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 28)),
      });
      final service = HabitHistoryService(db);
      final now = DateTime(2026, 10, 2);
      for (final day in [28, 30]) {
        await service.setCompleted(
          uid: 'u',
          habitId: 'h',
          date: DateTime(2026, 9, day),
          completed: true,
          retrospective: true,
          now: now,
        );
      }
      final result = await service.setCompleted(
        uid: 'u',
        habitId: 'h',
        date: now,
        completed: true,
        now: now,
      );
      expect(result.streak, 3);
      await expectLater(
        service.setCompleted(
          uid: 'u',
          habitId: 'h',
          date: DateTime(2026, 10, 1),
          completed: true,
          retrospective: true,
          now: now,
        ),
        throwsArgumentError,
      );
    },
  );
}
