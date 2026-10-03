import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/data/item_progress_service.dart';
import 'package:focusly/core/data/inbox_conversion_service.dart';
import 'package:focusly/features/relationship_health/services/relationship_health_service.dart';
import 'package:focusly/features/contacts/services/contacts_service.dart';
import 'package:focusly/features/skills/services/skills_service.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/time_audit/models/time_audit_model.dart';

void main() {
  test('task counter and group mirror commit the same partial value', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('groups/g/assignments/a').set({'type': 'task'});
    await db.doc('users/u/tasks/t').set({
      'done': false,
      'completionMode': 'count',
      'targetCount': 5,
      'currentCount': 0,
      'title': 'Original',
      'assignedByGroupId': 'g',
      'groupAssignmentId': 'a',
    });
    await ItemProgressService(db).task(uid: 'u', id: 't', done: true, count: 2);
    expect((await db.doc('users/u/tasks/t').get()).data()!['done'], false);
    final mirror = (await db.doc('groups/g/assignments/a/completions/u').get())
        .data()!;
    expect(mirror['currentCount'], 2);
    expect(mirror['status'], 'pending');
    expect(mirror['itemId'], 't');
    await expectLater(
      ItemProgressService(db).task(uid: 'u', id: 't', done: true, count: 6),
      throwsArgumentError,
    );
    expect((await db.doc('users/u/tasks/t').get()).data()!['currentCount'], 2);
  });
  test(
    'two stale count operations increment fresh state without replacing metadata',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u/habits/h').set({
        'title': 'New title',
        'completionMode': 'count',
        'targetCount': 4,
        'currentCount': 0,
      });
      final service = ItemProgressService(db);
      await service.habitCount(uid: 'u', id: 'h', delta: 1);
      await service.habitCount(uid: 'u', id: 'h', delta: 1);
      final data = (await db.doc('users/u/habits/h').get()).data()!;
      expect(data['currentCount'], 2);
      expect(data['title'], 'New title');
    },
  );
  test(
    'retrying inbox conversion creates one target; another destination fails',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u/inbox/i').set({
        'text': 'Captured',
        'processed': false,
      });
      final service = InboxConversionService(db);
      for (var i = 0; i < 3; i++) {
        await service.convert(
          uid: 'u',
          inboxId: 'i',
          collection: 'tasks',
          data: {'title': 'Task'},
        );
      }
      expect((await db.collection('users/u/tasks').get()).docs, hasLength(1));
      expect(
        (await db.doc('users/u/inbox/i').get()).data()!['processed'],
        true,
      );
      await expectLater(
        service.convert(uid: 'u', inboxId: 'i', collection: 'events', data: {}),
        throwsStateError,
      );
    },
  );
  test(
    'moving and deleting the newest interaction recomputes both contacts',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/u/contacts/a').set({'name': 'A'});
      await db.doc('users/u/contacts/b').set({'name': 'B'});
      final service = RelationshipHealthService(firestore: db);
      await service.addLog(
        uid: 'u',
        contactId: 'a',
        date: DateTime(2026, 9, 1),
      );
      final newest = await service.addLog(
        uid: 'u',
        contactId: 'a',
        date: DateTime(2026, 9, 10),
      );
      await service.deleteLog(uid: 'u', logId: newest!);
      expect(
        ((await db.doc('users/u/contacts/a').get()).data()!['lastContact']
                as Timestamp)
            .toDate(),
        DateTime(2026, 9, 1),
      );
      final first =
          (await db.collection('users/u/relationshipLogs').get()).docs.single;
      final model = (await service.streamLogs('u').first).single;
      expect(
        await service.updateLog(
          uid: 'u',
          currentLog: model,
          newContactId: 'b',
          newDate: DateTime(2026, 9, 1),
          newRating: 5,
        ),
        true,
      );
      expect(
        (await db.doc('users/u/contacts/a').get()).data()!['hasContacted'],
        false,
      );
      expect(
        (await db.doc('users/u/contacts/b').get()).data()!['hasContacted'],
        true,
      );
      expect(
        (await db.doc('users/u/relationshipLogs/${first.id}').get()).exists,
        true,
      );
      expect(
        await ContactsService(
          firestore: db,
        ).deleteContact(uid: 'u', contactId: 'b'),
        true,
      );
      expect(
        (await db.collection('users/u/relationshipLogs').get()).docs,
        isEmpty,
      );
    },
  );
  test(
    'skill reward is claimed once even after toggling a task again',
    () async {
      final db = FakeFirebaseFirestore();
      final service = SkillsService(firestore: db);
      await service.addSkill(uid: 'u', name: 'Skill', category: 'work');
      final task = TaskModel(
        id: 't',
        title: 'Task',
        categoryId: 'work',
        priority: TaskPriority.high,
        date: DateTime.now(),
        done: true,
        createdAt: DateTime.now(),
      );
      await service.awardTaskCompletionXp(uid: 'u', task: task);
      await service.awardTaskCompletionXp(uid: 'u', task: task);
      final data = (await db.collection('users/u/skills').get()).docs.single
          .data();
      expect(data['xp'], 25);
    },
  );
  test('recorded hours do not include priority estimates', () {
    final date = DateTime(2026, 10, 3);
    final task = TaskModel(
      id: 't',
      title: 'Task',
      categoryId: 'work',
      priority: TaskPriority.high,
      date: date,
      done: true,
      doneAt: date,
      createdAt: date,
    );
    final totals = computeCombinedCategoryHours(
      logs: [
        TimeAuditLogModel(
          id: 'l',
          category: 'work',
          hours: 1,
          date: date,
          createdAt: date,
        ),
      ],
      completedTasks: [task],
      period: 'all',
    );
    expect(totals['work'], 1);
  });
}
