import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/gtd/inbox_screen.dart';
import 'package:focusly/features/gtd/models/inbox_item_model.dart';
import 'package:focusly/features/gtd/providers/gtd_provider.dart';
import 'package:focusly/features/gtd/reference_screen.dart';
import 'package:focusly/features/gtd/someday_screen.dart';
import 'package:focusly/features/gtd/waiting_screen.dart';
import 'package:focusly/features/gtd/widgets/clarify_wizard_sheet.dart';
import 'package:focusly/features/gtd/widgets/quick_capture_sheet.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';

Widget createGtdTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_gtd'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('GTD Data Models & Serialization Tests', () {
    test('InboxItemModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 23, 10, 0);
      final item = InboxItemModel(
        id: 'inbox_123',
        text: 'Call accountant regarding Q3 tax filing',
        processed: false,
        createdAt: now,
      );

      final map = item.toMap();
      expect(map['id'], equals('inbox_123'));
      expect(map['text'], equals('Call accountant regarding Q3 tax filing'));
      expect(map['processed'], isFalse);

      final reconstructed = InboxItemModel.fromMap(map, 'inbox_123');
      expect(reconstructed.id, equals('inbox_123'));
      expect(reconstructed.text, equals('Call accountant regarding Q3 tax filing'));
      expect(reconstructed.processed, isFalse);

      final processedCopy = reconstructed.copyWith(processed: true);
      expect(processedCopy.processed, isTrue);
      expect(processedCopy.text, equals(reconstructed.text));
    });

    test('TaskModel GTD extensions (Waiting, Someday, Reference) serialize properly', () {
      final now = DateTime(2026, 8, 23);

      // Waiting For Task
      final waitingTask = TaskModel(
        id: 'wait_1',
        title: 'Review contract revisions',
        categoryId: 'work',
        priority: TaskPriority.medium,
        date: now,
        createdAt: now,
        listType: 'waiting',
        waitingFor: 'Legal Department',
        waitingSince: now.subtract(const Duration(days: 4)),
      );

      final waitingMap = waitingTask.toMap();
      expect(waitingMap['listType'], equals('waiting'));
      expect(waitingMap['waitingFor'], equals('Legal Department'));
      expect(waitingMap['waitingSince'], isNotNull);

      final reconstructedWaiting = TaskModel.fromMap(waitingMap, 'wait_1');
      expect(reconstructedWaiting.listType, equals('waiting'));
      expect(reconstructedWaiting.waitingFor, equals('Legal Department'));

      // Someday Task
      final somedayTask = TaskModel(
        id: 'someday_1',
        title: 'Learn SwiftUI development',
        categoryId: 'personal',
        priority: TaskPriority.low,
        date: now,
        createdAt: now,
        listType: 'someday',
      );
      final somedayMap = somedayTask.toMap();
      expect(somedayMap['listType'], equals('someday'));
      final reconstructedSomeday = TaskModel.fromMap(somedayMap, 'someday_1');
      expect(reconstructedSomeday.listType, equals('someday'));

      // Reference Task
      final refTask = TaskModel(
        id: 'ref_1',
        title: 'Server SSH Keys & IP Addresses',
        notes: '192.168.1.100 root key',
        categoryId: 'personal',
        date: now,
        createdAt: now,
        listType: 'reference',
      );
      final refMap = refTask.toMap();
      expect(refMap['listType'], equals('reference'));
      final reconstructedRef = TaskModel.fromMap(refMap, 'ref_1');
      expect(reconstructedRef.listType, equals('reference'));
      expect(reconstructedRef.notes, equals('192.168.1.100 root key'));
    });
  });

  group('GTD Riverpod Providers & Count Badge Tests', () {
    test('unprocessedInboxCountProvider accurately tallies unprocessed items', () async {
      final inboxItems = [
        InboxItemModel(
          id: '1',
          text: 'Item 1',
          processed: false,
          createdAt: DateTime.now(),
        ),
        InboxItemModel(
          id: '2',
          text: 'Item 2',
          processed: true,
          createdAt: DateTime.now(),
        ),
        InboxItemModel(
          id: '3',
          text: 'Item 3',
          processed: false,
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user_test'),
          inboxStreamProvider.overrideWith((ref) => Stream.value(inboxItems)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(inboxStreamProvider, (prev, next) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(unprocessedInboxCountProvider), equals(2));
    });

    test('GTD list providers partition tasks by listType correctly', () async {
      final now = DateTime.now();
      final allTasks = [
        TaskModel(
          id: 't1',
          title: 'Normal Active Task',
          categoryId: 'work',
          date: now,
          createdAt: now,
        ),
        TaskModel(
          id: 'w1',
          title: 'Waiting for report',
          categoryId: 'work',
          date: now,
          createdAt: now,
          listType: 'waiting',
          waitingFor: 'Manager',
        ),
        TaskModel(
          id: 's1',
          title: 'Someday learn piano',
          categoryId: 'personal',
          date: now,
          createdAt: now,
          listType: 'someday',
        ),
        TaskModel(
          id: 'r1',
          title: 'Wi-Fi Password note',
          categoryId: 'personal',
          date: now,
          createdAt: now,
          listType: 'reference',
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('user_test'),
          tasksStreamProvider.overrideWith((ref) => Stream.value(allTasks)),
        ],
      );
      addTearDown(container.dispose);

      container.listen(tasksStreamProvider, (prev, next) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final waiting = container.read(waitingTasksStreamProvider).value ?? [];
      expect(waiting.length, equals(1));
      expect(waiting.first.id, equals('w1'));

      final someday = container.read(somedayTasksStreamProvider).value ?? [];
      expect(someday.length, equals(1));
      expect(someday.first.id, equals('s1'));

      final reference = container.read(referenceTasksStreamProvider).value ?? [];
      expect(reference.length, equals(1));
      expect(reference.first.id, equals('r1'));
    });
  });

  group('GTD UI & Screen Widget Tests', () {
    testWidgets('InboxScreen renders items, filter chips, and empty states', (tester) async {
      final inboxItems = [
        InboxItemModel(
          id: 'item_1',
          text: 'Buy organic coffee beans',
          processed: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createGtdTestWidget(
          child: const InboxScreen(),
          overrides: [
            inboxStreamProvider.overrideWith((ref) => Stream.value(inboxItems)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GTD Inbox'), findsOneWidget);
      expect(find.text('Buy organic coffee beans'), findsOneWidget);
      expect(find.text('Clarify'), findsOneWidget);
      expect(find.text('Unprocessed'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Processed'), findsOneWidget);
    });

    testWidgets('WaitingScreen renders waiting tasks and waiting-for person badge', (tester) async {
      final now = DateTime.now();
      final tasks = [
        TaskModel(
          id: 'wait_1',
          title: 'Awaiting design feedback',
          categoryId: 'work',
          date: now,
          createdAt: now,
          listType: 'waiting',
          waitingFor: 'Alex Graphic Designer',
          waitingSince: now,
        ),
      ];

      await tester.pumpWidget(
        createGtdTestWidget(
          child: const WaitingScreen(),
          overrides: [
            tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Waiting For'), findsOneWidget);
      expect(find.text('Awaiting design feedback'), findsOneWidget);
      expect(find.text('Waiting for: Alex Graphic Designer'), findsOneWidget);
    });

    testWidgets('SomedayScreen renders someday ideas and review nudge banner', (tester) async {
      final now = DateTime.now();
      final tasks = [
        TaskModel(
          id: 'some_1',
          title: 'Hike Mount Fuji',
          categoryId: 'personal',
          date: now,
          createdAt: now,
          listType: 'someday',
        ),
      ];

      await tester.pumpWidget(
        createGtdTestWidget(
          child: const SomedayScreen(),
          overrides: [
            tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Someday / Maybe'), findsOneWidget);
      expect(find.text('Hike Mount Fuji'), findsOneWidget);
      expect(find.text('Promote to Task'), findsOneWidget);
      expect(find.textContaining('You have 1 someday ideas'), findsOneWidget);
    });

    testWidgets('ReferenceScreen renders reference cards and tags', (tester) async {
      final now = DateTime.now();
      final tasks = [
        TaskModel(
          id: 'ref_1',
          title: 'Emergency Contact Numbers',
          notes: 'Police: 122, Ambulance: 123',
          categoryId: 'personal',
          date: now,
          createdAt: now,
          listType: 'reference',
        ),
      ];

      await tester.pumpWidget(
        createGtdTestWidget(
          child: const ReferenceScreen(),
          overrides: [
            tasksStreamProvider.overrideWith((ref) => Stream.value(tasks)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reference'), findsWidgets);
      expect(find.text('Emergency Contact Numbers'), findsOneWidget);
      expect(find.text('Police: 122, Ambulance: 123'), findsOneWidget);
    });

    testWidgets('QuickCaptureSheet renders single line input and submit button', (tester) async {
      await tester.pumpWidget(
        createGtdTestWidget(
          child: const Scaffold(
            body: QuickCaptureSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('ClarifyWizardSheet executes multi-step decision state machine', (tester) async {
      final item = InboxItemModel(
        id: 'item_test',
        text: 'Fix leaking pipe in bathroom',
        processed: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createGtdTestWidget(
          child: Scaffold(
            body: ClarifyWizardSheet(inboxItem: item),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Actionable question
      expect(find.text('Does this need action?'), findsOneWidget);
      expect(find.text('Fix leaking pipe in bathroom'), findsOneWidget);
      expect(find.text('Yes, Actionable'), findsOneWidget);
      expect(find.text('No Action Needed'), findsOneWidget);

      // Tap Yes -> Step 2
      await tester.tap(find.text('Yes, Actionable'));
      await tester.pumpAndSettle();

      expect(find.text('Does it take less than 2 minutes?'), findsOneWidget);
      expect(find.text('Do it now!'), findsOneWidget);
      expect(find.text('Takes longer'), findsOneWidget);

      // Tap Takes longer -> Step 3
      await tester.tap(find.text('Takes longer'));
      await tester.pumpAndSettle();

      expect(find.text('When will you act on it?'), findsOneWidget);
      expect(find.text('Now / Next Action'), findsOneWidget);
      expect(find.text('Someday / Maybe'), findsOneWidget);
      expect(find.text('Waiting For (Delegated)'), findsOneWidget);
      expect(find.text('Calendar Event'), findsOneWidget);

      // Back navigation back to Step 2
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Does it take less than 2 minutes?'), findsOneWidget);
    });
  });
}
