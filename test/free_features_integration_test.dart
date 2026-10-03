import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/data/item_progress_service.dart';
import 'package:focusly/core/data/pending_operations.dart';
import 'package:focusly/core/data/pending_operations_processor.dart';
import 'package:focusly/core/data/firestore_provider.dart';
import 'package:focusly/features/productivity/providers/workspace_preferences.dart';
import 'package:focusly/features/productivity/services/study_session_service.dart';
import 'package:focusly/features/productivity/services/trash_service.dart';
import 'package:focusly/features/productivity/services/productivity_service.dart';
import 'package:focusly/features/productivity/analytics_page.dart';
import 'package:focusly/features/productivity/productivity_page.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';

TaskModel sample(String id, {bool done = false, DateTime? finished}) =>
    TaskModel(
      id: id,
      title: 'مهمة عربية طويلة للتحقق من الحفظ والتزامن',
      categoryId: 'study',
      date: DateTime(2026, 10, 3),
      createdAt: DateTime(2026, 10, 1),
      done: done,
      doneAt: finished,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'manual outbox recovery is account-scoped and reuses immutable completion identity',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/a').set({'groupIds': []});
      await db
          .doc('users/a/tasks/t')
          .set(
            sample('t', done: true, finished: DateTime(2026, 10, 3)).toMap(),
          );
      await PendingOperations.enqueue(
        'a',
        'reward',
        'task_t',
        {
          'sourceId': 't',
          'sourceType': 'task',
          'amount': 10,
          'label': 'Task',
        },
      );
      await PendingOperationsProcessor.drain(
        db,
        'a',
        manual: true,
        stillCurrent: () => false,
      );
      expect((await db.doc('users/a/stats/progress').get()).exists, false);
      await PendingOperationsProcessor.drain(
        db,
        'a',
        manual: true,
        stillCurrent: () => true,
      );
      expect((await db.doc('users/a/stats/progress').get()).data()?['xp'], 10);
      expect(await PendingOperations.list('a'), isEmpty);
      await PendingOperationsProcessor.drain(
        db,
        'a',
        manual: true,
        stillCurrent: () => true,
      );
      expect((await db.doc('users/a/stats/progress').get()).data()?['xp'], 10);
      expect((await db.doc('users/b/stats/progress').get()).exists, false);
    },
  );
  test(
    'completion-anchored recurrence creates one successor and skip advances exactly once',
    () async {
      final db = FakeFirebaseFirestore(),
          service = ProductivityService(FakeFirebaseFirestore());
      final tools = ProductivityService(db);
      final original = sample('anchor');
      await db.doc('users/u/tasks/anchor').set(original.toMap());
      await tools.saveRecurrence(
        'u',
        original,
        'interval',
        intervalDays: 3,
        afterCompletion: true,
      );
      await tools.materialize('u', DateTime(2026, 10, 3));
      expect((await db.collection('users/u/tasks').get()).docs, hasLength(1));
      await db.doc('users/u/tasks/anchor').update({
        'done': true,
        'doneAt': Timestamp.fromDate(DateTime(2026, 10, 5)),
      });
      for (var i = 0; i < 3; i++) {
        await tools.materialize('u', DateTime(2026, 10, 5));
      }
      final copies = (await db.collection('users/u/tasks').get()).docs;
      expect(copies, hasLength(2));
      final next = copies.singleWhere((doc) => doc.id != 'anchor');
      expect(next.data()['date'], Timestamp.fromDate(DateTime(2026, 10, 8)));
      await tools.skipOccurrence('u', next.id);
      await tools.materialize('u', DateTime(2026, 10, 8));
      await tools.materialize('u', DateTime(2026, 10, 8));
      final last = (await db.collection('users/u/tasks').get()).docs
          .singleWhere((doc) => doc.id != 'anchor');
      expect(last.data()['date'], Timestamp.fromDate(DateTime(2026, 10, 11)));
      expect(service, isA<ProductivityService>());
    },
  );
  test(
    'recurrence shifts the deadline with each dated occurrence and respects end/weekday limits',
    () async {
      final db = FakeFirebaseFirestore();
      final service = ProductivityService(db);
      final source = sample('dated').copyWith(deadline: DateTime(2026, 10, 5));
      await db.doc('users/u/tasks/dated').set(source.toMap());
      await service.saveRecurrence(
        'u',
        source,
        'daily',
        end: DateTime(2026, 10, 4),
        weekdays: [6, 7],
      );
      await service.materialize('u', DateTime(2026, 10, 3));
      final copies = (await db.collection('users/u/tasks').get()).docs;
      final next = copies.singleWhere((doc) => doc.id != 'dated').data();
      expect((next['deadline'] as Timestamp).toDate(), DateTime(2026, 10, 6));
      await service.materialize('u', DateTime(2026, 10, 5));
      expect((await db.collection('users/u/tasks').get()).docs, hasLength(2));
      expect(
        () => service.saveRecurrence(
          'u',
          source,
          'daily',
          end: DateTime(2026, 10, 1),
        ),
        throwsArgumentError,
      );
    },
  );
  test(
    'workspace template dates shift to the selected start and count habits reset completely',
    () async {
      final db = FakeFirebaseFirestore();
      final service = ProductivityService(db);
      await service.saveWorkspaceTemplate('u', 'dated', [
        {
          'collection': 'tasks',
          'id': 'a',
          'data': sample('a').copyWith(deadline: DateTime(2026, 10, 5)).toMap(),
        },
        {
          'collection': 'habits',
          'id': 'h',
          'data': {
            'title': 'Count',
            'days': List.filled(7, true),
            'completionMode': 'count',
            'targetCount': 5,
            'currentCount': 5,
            'isCompleted': true,
          },
        },
      ]);
      final template =
          (await db.collection('users/u/taskTemplates').get()).docs.single;
      await service.useTemplate(
        'u',
        template.id,
        'copy',
        DateTime(2026, 11, 1),
      );
      expect(
        (await db.doc('users/u/tasks/template_copy_0').get())
            .data()?['deadline'],
        Timestamp.fromDate(DateTime(2026, 11, 3)),
      );
      final habit = (await db.doc('users/u/habits/template_copy_1').get())
          .data()!;
      expect(habit['isCompleted'], false);
      expect(habit['currentCount'], 0);
      expect(habit['days'], List.filled(7, false));
    },
  );
  test(
    'task effects persist without a widget and remain scoped to the original account',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/a/tasks/t').set(sample('t').toMap());
      await ItemProgressService(db).task(uid: 'a', id: 't', done: true);
      expect(
        (await PendingOperations.list('a')).map((item) => item['kind']).toSet(),
        {'reward', 'skill'},
      );
      expect(await PendingOperations.list('b'), isEmpty);
      expect((await db.doc('users/a/tasks/t').get()).data()?['done'], true);
      expect((await db.doc('users/a/stats/progress').get()).exists, false);
    },
  );
  test(
    'concurrent preference edits preserve loaded preferences and both new values',
    () async {
      SharedPreferences.setMockInitialValues({
        'workspace_preferences_a': '{"weightUnit":"lb"}',
      });
      final container = ProviderContainer(
        overrides: [currentUserIdProvider.overrideWithValue('a')],
      );
      addTearDown(container.dispose);
      final settings = container.read(workspacePreferencesProvider.notifier);
      await Future.wait([
        settings.set('hiddenModules', ['finance']),
        settings.set('savedSearches', [
          {'query': 'book', 'collection': 'books'},
        ]),
      ]);
      expect(container.read(workspacePreferencesProvider)['weightUnit'], 'lb');
      expect(container.read(workspacePreferencesProvider)['hiddenModules'], [
        'finance',
      ]);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'workspace_preferences_a',
        ),
        contains('savedSearches'),
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'workspace_preferences_b',
        ),
        isNull,
      );
    },
  );
  test(
    'deleting and restoring a linked task recomputes its goal in the same transaction',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/a/tasks/t').set({
        ...sample('t', done: true, finished: DateTime(2026, 10, 3)).toMap(),
        'goalId': 'g',
        'milestoneTitle': 'Release',
      });
      await db.doc('users/a/goals/g').set({
        'milestones': [
          {'title': 'Release', 'done': true},
        ],
        'progress': 100,
        'taskLinks': {'t': 'Release'},
      });
      final bin = TrashService(db), key = await bin.move('a', 'tasks', 't');
      expect((await db.doc('users/a/goals/g').get()).data()?['progress'], 0);
      await bin.restore('a', key);
      expect((await db.doc('users/a/goals/g').get()).data()?['progress'], 100);
      expect((await db.doc('users/a/stats/progress').get()).exists, false);
    },
  );
  test(
    'study planning retries reuse one task and never grant a second reward for the source',
    () async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/a/books/b').set({
        'title': 'كتاب',
        'currentPage': 0,
        'totalPages': 100,
      });
      final service = StudySessionService(db), date = DateTime(2026, 10, 3);
      final first = await service.plan(
        uid: 'a',
        collection: 'books',
        sourceId: 'b',
        date: date,
      );
      final second = await service.plan(
        uid: 'a',
        collection: 'books',
        sourceId: 'b',
        date: date,
      );
      expect(first.id, second.id);
      expect(first.learningSource?['id'], 'b');
      expect(
        TaskModel.fromMap(
          first.toMap(),
          first.id,
        ).copyWith(title: 'Edited').learningSource?['id'],
        'b',
      );
      await ItemProgressService(db).task(uid: 'a', id: first.id, done: true);
      final jobs = await PendingOperations.list('a');
      expect(jobs, hasLength(1));
      expect((jobs.single['payload'] as Map)['amount'], 0);
      expect((await db.collection('users/a/tasks').get()).docs, hasLength(1));
    },
  );
  test(
    'dated comparison excludes unknown old completion dates and includes an overdue completion once',
    () {
      final start = DateTime(2026, 10, 1), end = DateTime(2026, 10, 8);
      final results = DatedTaskSummary(
        [
          sample(
            'known',
            done: true,
            finished: DateTime(2026, 10, 3),
          ).copyWith(date: DateTime(2026, 9, 1)),
          sample('unknown', done: true),
          sample('pending'),
        ],
        start,
        end,
      );
      expect(results.completed, hasLength(1));
      expect(results.eligible, hasLength(3));
      expect(results.unknown, 1);
      expect(results.percentage, 33);
    },
  );
  test(
    'mixed templates preserve copied project links while resetting real progress',
    () async {
      final db = FakeFirebaseFirestore(), date = DateTime(2026, 10, 3);
      final tools = ProductivityService(db);
      await tools.saveWorkspaceTemplate('a', 'Study', [
        {
          'collection': 'paraProjects',
          'id': 'p',
          'data': {'title': 'Project', 'archived': false},
        },
        {
          'collection': 'tasks',
          'id': 't',
          'data': {...sample('t', done: true).toMap(), 'projectId': 'p'},
        },
        {
          'collection': 'habits',
          'id': 'h',
          'data': {
            'title': 'Read daily',
            'days': List.filled(7, true),
            'streak': 50,
            'baseStreak': 50,
            'createdAt': Timestamp.fromDate(date),
          },
        },
      ]);
      final template =
          (await db.collection('users/a/taskTemplates').get()).docs.single;
      await tools.useTemplate('a', template.id, 'run', date);
      await tools.useTemplate('a', template.id, 'run', date);
      final task = (await db.collection('users/a/tasks').get()).docs.single;
      final habit = (await db.collection('users/a/habits').get()).docs.single;
      expect(task.data()['done'], false);
      expect(task.data()['projectId'], 'template_run_0');
      expect(habit.data()['streak'], 0);
      expect(habit.data()['days'], List.filled(7, false));
    },
  );
  testWidgets(
    'Arabic productivity templates render at a narrow width with large text and error-free bulk selection',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.doc('users/a/tasks/t').set(sample('t').toMap());
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('a'),
            firestoreProvider.overrideWithValue(db),
            tasksStreamProvider.overrideWith(
              (ref) => Stream.value([sample('t')]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.4)),
              child: child!,
            ),
            home: const ProductivityPage(initialTab: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('قالب مشروع وعادات وروتين'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
