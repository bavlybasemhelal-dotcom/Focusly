import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/features/tasks/models/task_model.dart';

void main() {
  group('Subtask Model Edit Tests', () {
    test('SubtaskModel copyWith correctly updates title', () {
      final original = SubtaskModel(
        id: 'sub_1',
        title: 'Original Title',
        done: false,
      );

      final edited = original.copyWith(title: 'Updated Subtask Title');

      expect(edited.id, 'sub_1');
      expect(edited.title, 'Updated Subtask Title');
      expect(edited.done, isFalse);
    });

    test('TaskModel subtask list update correctly replaces target subtask', () {
      final task = TaskModel(
        id: 'task_1',
        title: 'Main Task',
        categoryId: 'work',
        date: DateTime.now(),
        done: false,
        subtasks: [
          SubtaskModel(id: 's1', title: 'Subtask 1', done: false),
          SubtaskModel(id: 's2', title: 'Subtask 2', done: false),
        ],
        createdAt: DateTime.now(),
      );

      final updatedSubtasks = task.subtasks.map((s) {
        if (s.id == 's1') {
          return s.copyWith(title: 'Subtask 1 Edited');
        }
        return s;
      }).toList();

      final updatedTask = task.copyWith(subtasks: updatedSubtasks);

      expect(updatedTask.subtasks[0].title, 'Subtask 1 Edited');
      expect(updatedTask.subtasks[1].title, 'Subtask 2');
    });
  });

  group('Subtask Edit Localization Tests', () {
    final enLoc = AppLocalizations(const Locale('en'));
    final arLoc = AppLocalizations(const Locale('ar'));

    test('English translations exist for subtask edit keys', () {
      final editTitle = enLoc.tr('edit_subtask');
      expect(editTitle, isNotEmpty);
      expect(editTitle, isNot(equals('edit_subtask')));
      expect(editTitle, 'Edit Subtask');

      final hint = enLoc.tr('subtask_title_hint');
      expect(hint, isNotEmpty);
      expect(hint, isNot(equals('subtask_title_hint')));
    });

    test('Arabic translations exist for subtask edit keys', () {
      final editTitle = arLoc.tr('edit_subtask');
      expect(editTitle, isNotEmpty);
      expect(editTitle, isNot(equals('edit_subtask')));
      expect(editTitle, 'تعديل المهمة الفرعية');

      final hint = arLoc.tr('subtask_title_hint');
      expect(hint, isNotEmpty);
      expect(hint, isNot(equals('subtask_title_hint')));
    });
  });
}
