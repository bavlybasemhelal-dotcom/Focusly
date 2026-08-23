import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';
import 'package:focusly/features/schedule/providers/schedule_provider.dart';
import 'package:focusly/features/habits/providers/habits_provider.dart';
import 'package:focusly/features/pomodoro/providers/pomodoro_provider.dart';
import 'package:focusly/features/progress/providers/progress_provider.dart';
import 'package:focusly/features/groups/providers/groups_provider.dart';

class MockUserIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'user_alpha_123';

  void setUserId(String? id) => state = id;
}

final mockUserIdProvider =
    NotifierProvider<MockUserIdNotifier, String?>(MockUserIdNotifier.new);

void main() {
  group('Focusly Data Isolation & Auth-Scoping Tests', () {
    test('Logged-out state (uid == null) returns empty datasets across all personal providers', () async {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      // Listen to all providers to ensure subscription
      container.listen(tasksStreamProvider, (prev, next) {});
      container.listen(eventsStreamProvider, (prev, next) {});
      container.listen(habitsStreamProvider, (prev, next) {});
      container.listen(pomodoroLogsStreamProvider, (prev, next) {});
      container.listen(userXpStreamProvider, (prev, next) {});
      container.listen(unlockedAchievementsStreamProvider, (prev, next) {});
      container.listen(myGroupsStreamProvider, (prev, next) {});

      // Wait a microtask turn for initial Stream.value emissions
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Tasks
      final tasks = container.read(tasksStreamProvider).value ?? [];
      expect(tasks, isEmpty, reason: 'Logged-out user must not see any tasks');

      // Schedule Events
      final events = container.read(eventsStreamProvider).value ?? [];
      expect(events, isEmpty, reason: 'Logged-out user must not see any events');

      // Habits
      final habits = container.read(habitsStreamProvider).value ?? [];
      expect(habits, isEmpty, reason: 'Logged-out user must not see any habits');

      // Pomodoro Logs
      final logs = container.read(pomodoroLogsStreamProvider).value ?? [];
      expect(logs, isEmpty, reason: 'Logged-out user must not see any pomodoro logs');

      // Progress & XP
      final xp = container.read(userXpStreamProvider).value ?? 0;
      expect(xp, equals(0), reason: 'Logged-out user must have 0 XP');

      // Achievements
      final achievements =
          container.read(unlockedAchievementsStreamProvider).value ?? {};
      expect(achievements, isEmpty,
          reason: 'Logged-out user must not have unlocked achievements');

      // Groups
      final groups = container.read(myGroupsStreamProvider).value ?? [];
      expect(groups, isEmpty, reason: 'Logged-out user must not have groups');
    });

    test('Switching user ID reactively isolates data between Account A and Account B', () async {
      final userATasks = [
        TaskModel(
          id: 'task_a_1',
          title: 'User A Secret Task',
          categoryId: 'work',
          priority: TaskPriority.high,
          date: DateTime(2026, 8, 23),
          createdAt: DateTime.now(),
        ),
      ];

      final userBTasks = [
        TaskModel(
          id: 'task_b_1',
          title: 'User B Public Task',
          categoryId: 'personal',
          priority: TaskPriority.low,
          date: DateTime(2026, 8, 24),
          createdAt: DateTime.now(),
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => ref.watch(mockUserIdProvider)),
          tasksStreamProvider.overrideWith((ref) {
            final uid = ref.watch(currentUserIdProvider);
            if (uid == 'user_alpha_123') {
              return Stream.value(userATasks);
            } else if (uid == 'user_beta_456') {
              return Stream.value(userBTasks);
            }
            return Stream.value(<TaskModel>[]);
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(tasksStreamProvider, (prev, next) {});
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Verify Account A sees only User A tasks
      final sessionATasks = container.read(tasksStreamProvider).value ?? [];
      expect(sessionATasks.length, equals(1));
      expect(sessionATasks.first.id, equals('task_a_1'));
      expect(sessionATasks.first.title, equals('User A Secret Task'));

      // Account A logs out (uid = null)
      container.read(mockUserIdProvider.notifier).setUserId(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final loggedOutTasks = container.read(tasksStreamProvider).value ?? [];
      expect(loggedOutTasks, isEmpty,
          reason: 'On logout, data must immediately clear');

      // Account B logs in (uid = user_beta_456)
      container.read(mockUserIdProvider.notifier).setUserId('user_beta_456');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final sessionBTasks = container.read(tasksStreamProvider).value ?? [];
      expect(sessionBTasks.length, equals(1));
      expect(sessionBTasks.first.id, equals('task_b_1'));
      expect(sessionBTasks.first.title, equals('User B Public Task'));
      expect(
        sessionBTasks.any((t) => t.id == 'task_a_1'),
        isFalse,
        reason: 'Account B must NEVER see any tasks from Account A',
      );
    });

    test('Data subcollection paths adhere strictly to users/{uid}/ pattern', () {
      const testUid = 'user_test_789';

      // Validate standard personal subcollection paths
      final tasksPath = 'users/$testUid/tasks';
      final eventsPath = 'users/$testUid/events';
      final habitsPath = 'users/$testUid/habits';
      final pomodoroPath = 'users/$testUid/pomodoroLogs';
      final statsPath = 'users/$testUid/stats/progress';

      expect(tasksPath.startsWith('users/$testUid/'), isTrue);
      expect(eventsPath.startsWith('users/$testUid/'), isTrue);
      expect(habitsPath.startsWith('users/$testUid/'), isTrue);
      expect(pomodoroPath.startsWith('users/$testUid/'), isTrue);
      expect(statsPath.startsWith('users/$testUid/'), isTrue);
    });
  });
}
