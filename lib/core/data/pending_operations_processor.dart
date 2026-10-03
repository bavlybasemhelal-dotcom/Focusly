import 'package:cloud_firestore/cloud_firestore.dart';
import 'pending_operations.dart';
import 'completion_ledger.dart';
import '../../features/skills/services/skills_service.dart';
import '../../features/tasks/models/task_model.dart';

/// Shared recovery path for the session banner and the outbox screen.
class PendingOperationsProcessor {
  static final _running = <String>{};
  static Future<void> drain(
    FirebaseFirestore db,
    String account, {
    bool manual = false,
    required bool Function() stillCurrent,
  }) async {
    if (!_running.add(account)) return;
    try {
      for (final job in (await PendingOperations.list(
        account,
      )).take(manual ? 50 : 10)) {
        if (!stillCurrent()) return;
        if (!manual && (job['attempts'] as num) >= 5) continue;
        try {
          final payload = Map<String, dynamic>.from(job['payload'] as Map);
          if (job['kind'] == 'pomodoro') {
            final target = db
                .collection('users')
                .doc(account)
                .collection('pomodoroLogs')
                .doc(job['id'] as String);
            final data = {
              ...payload,
              'date': Timestamp.fromDate(
                DateTime.parse(payload['date'] as String),
              ),
              'createdAt': Timestamp.fromDate(
                DateTime.parse(payload['createdAt'] as String),
              ),
            };
            await db.runTransaction((transaction) async {
              final previous = await transaction.get(target);
              if (!previous.exists) transaction.set(target, data);
            });
            final seconds = (payload['durationSeconds'] as num).toInt();
            if (seconds >= 300) {
              final ledger = CompletionLedger(db);
              await ledger.award(
                uid: account,
                eventId: 'pomodoro_${target.id}',
                sourceId: target.id,
                sourceType: 'pomodoro',
                amount: (seconds / 50).floor().clamp(
                  1,
                  payload['partial'] == true ? 29 : 30,
                ),
                label: payload['taskTitle'] as String,
              );
              await ledger.syncGroups(
                uid: account,
                eventId: 'pomodoro_${target.id}',
              );
            }
          } else if (job['kind'] == 'skill') {
            final source = await db
                .collection('users')
                .doc(account)
                .collection('tasks')
                .doc(job['id'] as String)
                .get();
            if (source.data()?['done'] != true) {
              throw StateError('Waiting for task completion');
            }
            await SkillsService(firestore: db).awardTaskCompletionXp(
              uid: account,
              task: TaskModel.fromMap({
                ...source.data()!,
                ...payload,
              }, source.id),
              throwOnFailure: true,
            );
          } else if (job['kind'] == 'reward') {
            final ledger = CompletionLedger(db);
            await ledger.award(
              uid: account,
              eventId: job['id'] as String,
              sourceId: payload['sourceId'] as String,
              sourceType: payload['sourceType'] as String,
              amount: (payload['amount'] as num).toInt(),
              label: payload['label'] as String,
            );
            await ledger.syncGroups(uid: account, eventId: job['id'] as String);
          } else {
            throw StateError('Unsupported pending operation');
          }
          await PendingOperations.acknowledge(
            account,
            job['kind'] as String,
            job['id'] as String,
          );
        } catch (error) {
          await PendingOperations.failed(job, error);
        }
      }
    } finally {
      _running.remove(account);
    }
  }
}
