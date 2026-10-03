import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/tasks/models/task_model.dart';

void main() {
  group('Eisenhower Matrix Quadrant Computation Tests', () {
    test('Computes Q1 (Do Now) for Urgent + Important task', () {
      final now = DateTime.now();
      final urgentImportantTask = TaskModel(
        id: '1',
        title: 'Fix critical production crash',
        categoryId: 'work',
        priority: TaskPriority.high,
        date: now,
        createdAt: now,
      );

      expect(computeQuadrant(urgentImportantTask), EisenhowerQuadrant.q1DoNow);
      expect(urgentImportantTask.computedQuadrant, EisenhowerQuadrant.q1DoNow);
    });

    test('Computes Q2 (Schedule) for Important + Not Urgent task', () {
      final now = DateTime.now();
      final importantNotUrgentTask = TaskModel(
        id: '2',
        title: 'Learn Advanced Flutter Architecture',
        categoryId: 'study',
        priority: TaskPriority.high,
        date: now.add(const Duration(days: 10)),
        createdAt: now,
      );

      expect(
        computeQuadrant(importantNotUrgentTask),
        EisenhowerQuadrant.q2Schedule,
      );
      expect(
        importantNotUrgentTask.computedQuadrant,
        EisenhowerQuadrant.q2Schedule,
      );
    });

    test('Computes Q3 (Delegate) for Urgent + Not Important task', () {
      final now = DateTime.now();
      final urgentNotImportantTask = TaskModel(
        id: '3',
        title: 'Reply to casual survey email',
        categoryId: 'personal',
        priority: TaskPriority.low,
        date: now,
        createdAt: now,
      );

      expect(
        computeQuadrant(urgentNotImportantTask),
        EisenhowerQuadrant.q3Delegate,
      );
      expect(
        urgentNotImportantTask.computedQuadrant,
        EisenhowerQuadrant.q3Delegate,
      );
    });

    test('Computes Q4 (Eliminate) for Neither Urgent nor Important task', () {
      final now = DateTime.now();
      final neitherTask = TaskModel(
        id: '4',
        title: 'Organize old archived files',
        categoryId: 'personal',
        priority: TaskPriority.low,
        date: now.add(const Duration(days: 14)),
        createdAt: now,
      );

      expect(computeQuadrant(neitherTask), EisenhowerQuadrant.q4Eliminate);
      expect(neitherTask.computedQuadrant, EisenhowerQuadrant.q4Eliminate);
    });

    test('Deadline within 48 hours makes task urgent', () {
      final now = DateTime.now();
      final deadlineTask = TaskModel(
        id: '5',
        title: 'Course Final Project Submission',
        categoryId: 'courses',
        priority: TaskPriority.medium,
        date: now.add(const Duration(days: 7)),
        deadline: now.add(const Duration(hours: 24)),
        createdAt: now,
      );

      expect(computeQuadrant(deadlineTask), EisenhowerQuadrant.q1DoNow);
    });
  });

  group('Eisenhower Matrix Quadrant Drop Rules Tests', () {
    final now = DateTime.now();
    final baseTask = TaskModel(
      id: 'test_task',
      title: 'Sample Task',
      categoryId: 'work',
      priority: TaskPriority.medium,
      date: now.add(const Duration(days: 3)),
      deadline: now.add(const Duration(days: 5)),
      createdAt: now,
    );

    test('Dropping into Q1 sets priority=high and date=today', () {
      final result = applyQuadrantRule(baseTask, EisenhowerQuadrant.q1DoNow);
      expect(result.priority, TaskPriority.high);
      expect(result.date.day, now.day);
      expect(result.date.month, now.month);
    });

    test('Dropping into Q2 sets priority=high and date=+7 days', () {
      final result = applyQuadrantRule(baseTask, EisenhowerQuadrant.q2Schedule);
      expect(result.priority, TaskPriority.high);
      expect(result.date.isAfter(now.add(const Duration(days: 5))), isTrue);
    });

    test('Dropping into Q3 sets priority=low and date=today', () {
      final result = applyQuadrantRule(baseTask, EisenhowerQuadrant.q3Delegate);
      expect(result.priority, TaskPriority.low);
      expect(result.date.day, now.day);
    });

    test(
      'Dropping into Q4 sets priority=low, date=+7 days, and clears deadline',
      () {
        final result = applyQuadrantRule(
          baseTask,
          EisenhowerQuadrant.q4Eliminate,
        );
        expect(result.priority, TaskPriority.low);
        expect(result.date.isAfter(now.add(const Duration(days: 5))), isTrue);
        expect(result.deadline, isNull);
      },
    );
  });

  group('SubtaskModel & Progress Tests', () {
    test('Calculates completedSubtasksCount correctly', () {
      final task = TaskModel(
        id: 'task_sub',
        title: 'Project milestone',
        categoryId: 'work',
        date: DateTime.now(),
        subtasks: const [
          SubtaskModel(id: 's1', title: 'Design DB', done: true),
          SubtaskModel(id: 's2', title: 'Write APIs', done: true),
          SubtaskModel(id: 's3', title: 'Build UI', done: false),
          SubtaskModel(id: 's4', title: 'Deploy', done: false),
        ],
        createdAt: DateTime.now(),
      );

      expect(task.completedSubtasksCount, 2);
      expect(task.subtasks.length, 4);
    });
  });
}
