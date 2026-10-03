import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/features/focus_mode/providers/focus_mode_provider.dart';
import 'package:focusly/features/pomodoro/providers/pomodoro_provider.dart';
import 'package:focusly/features/spaced_repetition/models/flashcard_model.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/features/tasks/widgets/add_edit_task_sheet.dart';
import 'package:focusly/features/tasks/tasks_screen.dart';
import 'package:focusly/features/time_audit/models/time_audit_model.dart';

class SessionUid extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void change(String? uid) => state = uid;
}

final sessionUidProvider = NotifierProvider<SessionUid, String?>(
  SessionUid.new,
);

class RetryTasksController extends TasksController {
  int attempts = 0;
  TaskModel? saved;
  @override
  Future<bool> addTask(
    TaskModel task,
    BuildContext context, {
    String? inboxId,
  }) async {
    attempts++;
    if (attempts == 1) return false;
    saved = task;
    return true;
  }
}

void main() {
  final date = DateTime(2026, 10, 2);
  TaskModel task({String? notes, DateTime? doneAt}) => TaskModel(
    id: 'task',
    title: 'Test',
    categoryId: 'work',
    notes: notes,
    date: DateTime(2026, 8, 1),
    createdAt: date,
    done: true,
    doneAt: doneAt,
  );

  test('task notes can be cleared without clearing unrelated fields', () {
    final original = task(notes: 'Old notes');
    expect(original.copyWith(title: 'Edited').notes, 'Old notes');
    expect(original.copyWith(clearNotes: true).notes, isNull);
    expect(original.copyWith(clearNotes: true).categoryId, 'work');
  });
  test(
    'time audit excludes future dates and does not invent hours from priorities',
    () {
      expect(isDateInPeriod(DateTime(2026, 10, 3), 'week', date), isFalse);
      final hours = computeCombinedCategoryHours(
        logs: [],
        completedTasks: [task(doneAt: date)],
        period: 'week',
        now: date,
      );
      expect(hours['work'], isNull);
    },
  );
  test('flashcard due evaluation handles past, same and future dates', () {
    final card = FlashcardModel(
      id: 'c',
      front: 'Q',
      back: 'A',
      dueDate: '2026-10-02',
      createdAt: date,
      updatedAt: date,
    );
    expect(card.isDueOn(DateTime(2026, 10, 1)), isFalse);
    expect(card.isDueOn(date), isTrue);
    expect(card.isDueOn(DateTime(2026, 10, 3)), isTrue);
  });
  test(
    'account changes reset the active focus task, mode and category filter',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith(
            (ref) => ref.watch(sessionUidProvider),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(pomodoroTimerProvider, (_, _) {});
      container.listen(focusModeActiveProvider, (_, _) {});
      container.listen(selectedCategoryFilterProvider, (_, _) {});
      container
          .read(pomodoroTimerProvider.notifier)
          .setSelectedTask('private-task', 'Alice private task');
      container.read(focusModeActiveProvider.notifier).enterFocusMode();
      container
          .read(selectedCategoryFilterProvider.notifier)
          .setFilter('alice-category');
      container.read(sessionUidProvider.notifier).change('bob');
      await container.pump();
      expect(container.read(pomodoroTimerProvider).selectedTaskId, isNull);
      expect(container.read(pomodoroTimerProvider).isRunning, isFalse);
      expect(container.read(focusModeActiveProvider), isFalse);
      expect(container.read(selectedCategoryFilterProvider), 'all');
    },
  );
  testWidgets(
    'failed task save keeps entered text and allows a successful retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = RetryTasksController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            tasksControllerProvider.overrideWithValue(controller),
          ],
          child: MaterialApp(
            localizationsDelegates: const [AppLocalizations.delegate],
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AddEditTaskSheet.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Keep my task');
      final save = find.widgetWithText(ElevatedButton, 'Create Task');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(AddEditTaskSheet), findsOneWidget);
      expect(find.text('Keep my task'), findsOneWidget);
      expect(
        find.text(
          'Could not save the task. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(controller.attempts, 2);
      expect(controller.saved?.title, 'Keep my task');
      expect(find.byType(AddEditTaskSheet), findsNothing);
    },
  );
  testWidgets(
    'task read failures show an error and retry action instead of an empty list',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue(null),
            tasksStreamProvider.overrideWith(
              (ref) => Stream.error(StateError('permission denied')),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: [AppLocalizations.delegate],
            home: TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not load your tasks. Check your connection and retry.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    },
  );
}
