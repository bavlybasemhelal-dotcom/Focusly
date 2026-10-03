import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/task_model.dart';

Future<int?> showTaskCountDialog(BuildContext context, TaskModel task) {
  var count = task.currentCount;
  final target = task.targetCount ?? 1;
  return showDialog<int>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (dialog, update) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count / $target',
              style: Theme.of(dialog).textTheme.headlineMedium,
            ),
            LinearProgressIndicator(value: (count / target).clamp(0, 1)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: context.tr('decrease_progress'),
                  onPressed: count > 0 ? () => update(() => count--) : null,
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  tooltip: context.tr('increase_progress'),
                  onPressed: count < target
                      ? () => update(() => count++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, count),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    ),
  );
}
