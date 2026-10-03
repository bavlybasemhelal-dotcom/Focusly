import 'pending_operations.dart';

/// Save intended effects before the source transaction; server proof is still required.
class CompletionIntents {
  static Future<void> task(
    String uid,
    String id,
    Map<String, dynamic> data,
  ) async {
    await PendingOperations.enqueue(uid, 'reward', 'task_$id', {
      'sourceId': id,
      'sourceType': 'task',
      'amount':
          data['assignedByGroupId'] == null && data['learningSource'] == null
          ? 10
          : 0,
      'label': data['title'] as String? ?? '',
    });
    if (data['assignedByGroupId'] == null && data['learningSource'] == null) {
      await PendingOperations.enqueue(uid, 'skill', id, {
        for (final key in ['title', 'priority', 'categoryId', 'skillId'])
          key: data[key],
      });
    }
  }

  static Future<void> habit(
    String uid,
    String id,
    String date,
    Map<String, dynamic> data,
  ) => PendingOperations.enqueue(uid, 'reward', 'habit_${id}_$date', {
    'sourceId': id,
    'sourceType': 'habit',
    'amount': data['assignedByGroupId'] == null ? 5 : 0,
    'label': data['title'] as String? ?? '',
  });
}
