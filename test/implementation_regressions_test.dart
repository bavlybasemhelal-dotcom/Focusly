import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/data/firestore_provider.dart';
import 'package:focusly/core/data/completion_ledger.dart';
import 'package:focusly/features/habits/services/habit_history_service.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/learning_paths/services/learning_paths_service.dart';
import 'package:focusly/features/learning_paths/models/learning_path_model.dart';
import 'package:focusly/features/notifications/providers/notifications_provider.dart';
import 'package:focusly/features/spaced_repetition/controllers/review_session_controller.dart';
import 'package:focusly/features/spaced_repetition/helpers/sm2_algorithm.dart';
import 'package:focusly/features/spaced_repetition/models/flashcard_model.dart';
import 'package:focusly/features/spaced_repetition/services/flashcards_service.dart';

class SessionAccount extends Notifier<String?> {
  @override
  String? build() => 'alice';
  void change(String? uid) => state = uid;
}

final account = NotifierProvider<SessionAccount, String?>(SessionAccount.new);

class ReviewStorage extends FlashcardsService {
  ReviewStorage({this.fail = false})
    : super(firestore: FakeFirebaseFirestore());
  final bool fail;
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<bool> saveReviewProgress({
    required String uid,
    required FlashcardModel updatedCard,
  }) async {
    calls++;
    await gate.future;
    return !fail;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final date = DateTime(2026, 10, 3);
  FlashcardModel card(String id) => FlashcardModel(
    id: id,
    front: 'Private $id',
    back: 'Answer',
    dueDate: '2026-10-03',
    createdAt: date,
    updatedAt: date,
  );
  ProviderContainer session() => ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
    ],
  );

  test('failed review keeps the card, score and retry available', () async {
    final container = session();
    addTearDown(container.dispose);
    final service = ReviewStorage(fail: true)..gate.complete();
    final controller = container.read(reviewSessionControllerProvider.notifier)
      ..startSession([card('1')]);
    expect(
      await controller.submitRating(quality: 4, uid: 'alice', service: service),
      false,
    );
    final result = container.read(reviewSessionControllerProvider);
    expect(result.currentCard?.id, '1');
    expect(result.totalReviewed, 0);
    expect(result.isSaving, false);
    expect(result.isCompleted, false);
  });

  test('concurrent review clicks save one card and advance once', () async {
    final container = session();
    addTearDown(container.dispose);
    final service = ReviewStorage();
    final controller = container.read(reviewSessionControllerProvider.notifier)
      ..startSession([card('1'), card('2')]);
    final first = controller.submitRating(
      quality: 3,
      uid: 'alice',
      service: service,
    );
    expect(
      await controller.submitRating(quality: 4, uid: 'alice', service: service),
      false,
    );
    service.gate.complete();
    expect(await first, true);
    expect(service.calls, 1);
    expect(container.read(reviewSessionControllerProvider).currentIndex, 1);
  });

  test(
    'account switch clears private cards and ignores old async result',
    () async {
      final container = session();
      addTearDown(container.dispose);
      container.listen(reviewSessionControllerProvider, (_, _) {});
      final service = ReviewStorage();
      final controller = container.read(
        reviewSessionControllerProvider.notifier,
      )..startSession([card('alice')]);
      final pending = controller.submitRating(
        quality: 3,
        uid: 'alice',
        service: service,
      );
      container.read(account.notifier).change('bob');
      await container.pump();
      service.gate.complete();
      expect(await pending, false);
      expect(container.read(reviewSessionControllerProvider).queue, isEmpty);
      expect(container.read(reviewSessionControllerProvider).totalReviewed, 0);
    },
  );

  test(
    'notification stream switches accounts and batch actions cover large histories',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore.doc('users/bob/notificationLog/private').set({
        'title': 'Bob',
        'createdAt': date,
        'read': false,
      });
      for (var i = 0; i < 430; i++) {
        await firestore.doc('users/alice/notificationLog/$i').set({
          'title': 'Alice',
          'createdAt': date,
          'read': false,
        });
      }
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(account)),
          firestoreProvider.overrideWithValue(firestore),
        ],
      );
      addTearDown(container.dispose);
      container.listen(notificationLogsStreamProvider, (_, _) {});
      expect(
        (await container.read(notificationLogsStreamProvider.future)).length,
        200,
      );
      expect(
        await container.read(notificationsControllerProvider).markAllAsRead(),
        true,
      );
      expect(
        (await firestore
                .collection('users/alice/notificationLog')
                .where('read', isEqualTo: false)
                .get())
            .docs,
        isEmpty,
      );
      container.read(account.notifier).change('bob');
      await container.pump();
      expect(
        (await container.read(
          notificationLogsStreamProvider.future,
        )).single.title,
        'Bob',
      );
      expect(
        await container
            .read(notificationsControllerProvider)
            .clearAllNotifications(),
        true,
      );
      expect(
        (await firestore.collection('users/alice/notificationLog').get())
            .docs
            .length,
        430,
      );
    },
  );

  test('SM2 rejects invalid ratings and scheduling parameters', () {
    expect(
      () => Sm2Algorithm.calculate(
        currentInterval: 0,
        currentRepetitions: 0,
        currentEaseFactor: 2.5,
        quality: 99,
      ),
      throwsArgumentError,
    );
    expect(
      () => Sm2Algorithm.calculate(
        currentInterval: -1,
        currentRepetitions: 0,
        currentEaseFactor: double.nan,
        quality: 3,
      ),
      throwsArgumentError,
    );
  });

  test(
    'stable completion awards are exactly once and isolated by account',
    () async {
      final store = FakeFirebaseFirestore();
      final ledger = CompletionLedger(store);
      for (var attempt = 0; attempt < 10; attempt++) {
        expect(
          await ledger.award(
            uid: 'alice',
            eventId: 'task_t',
            sourceId: 't',
            sourceType: 'task',
            amount: 10,
            label: 'Task',
          ),
          attempt == 0,
        );
      }
      expect(
        (await store.doc('users/alice/stats/progress').get()).data()?['xp'],
        10,
      );
      expect(
        (await store.collection('users/alice/completionEvents').get())
            .docs
            .length,
        1,
      );
      await ledger.award(
        uid: 'bob',
        eventId: 'task_t',
        sourceId: 't',
        sourceType: 'task',
        amount: 10,
        label: 'Bob task',
      );
      expect(
        (await store.doc('users/bob/stats/progress').get()).data()?['xp'],
        10,
      );
    },
  );

  test(
    'independent changes from stale learning paths preserve both days',
    () async {
      final store = FakeFirebaseFirestore();
      final service = LearningPathsService(firestore: store);
      final id = (await service.addPath(
        uid: 'alice',
        title: 'Path',
        totalDays: 2,
      ))!;
      final original = LearningPathModel.fromMap(
        (await store.doc('users/alice/learningPaths/$id').get()).data()!,
        id,
      );
      expect(
        await service.toggleStepCompletion(
          uid: 'alice',
          path: original,
          day: 1,
        ),
        true,
      );
      expect(
        await service.toggleStepCompletion(
          uid: 'alice',
          path: original,
          day: 2,
        ),
        true,
      );
      final updated = LearningPathModel.fromMap(
        (await store.doc('users/alice/learningPaths/$id').get()).data()!,
        id,
      );
      expect(updated.steps.every((step) => step.completed), true);
      expect(updated.progressDay, 2);
    },
  );

  test(
    'habit history has calendar streaks and cannot record future days',
    () async {
      final store = FakeFirebaseFirestore();
      final habit = HabitModel.create(
        id: 'h',
        title: 'Habit',
      ).copyWith(createdAt: DateTime(2026, 9, 1));
      await store.doc('users/alice/habits/h').set(habit.toMap());
      final history = HabitHistoryService(store);
      await history.setCompleted(
        uid: 'alice',
        habitId: 'h',
        date: DateTime(2026, 10, 1),
        completed: true,
        retrospective: true,
        now: date,
      );
      final gap = await history.setCompleted(
        uid: 'alice',
        habitId: 'h',
        date: date,
        completed: true,
        now: date,
      );
      expect(gap.streak, 1);
      final consecutive = await history.setCompleted(
        uid: 'alice',
        habitId: 'h',
        date: DateTime(2026, 10, 2),
        completed: true,
        retrospective: true,
        now: date,
      );
      expect(consecutive.streak, 3);
      await expectLater(
        history.setCompleted(
          uid: 'alice',
          habitId: 'h',
          date: DateTime(2026, 10, 4),
          completed: true,
          now: date,
        ),
        throwsArgumentError,
      );
      await history.setCompleted(
        uid: 'alice',
        habitId: 'h',
        date: date,
        completed: true,
        now: date,
      );
      expect(
        (await store.collection('users/alice/habitLogs').get()).docs.length,
        3,
      );
    },
  );
}
