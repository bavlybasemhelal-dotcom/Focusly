import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/calendar_clock.dart';
import '../../../core/data/completion_ledger.dart';
import '../../../core/data/goal_task_derivation.dart';
import '../../tasks/models/task_model.dart';

class PlanSuggestion {
  const PlanSuggestion(this.task, this.minutes, this.reason, this.score);
  final TaskModel task;
  final int minutes;
  final String reason;
  final int score;
}

/// These tools use only local calculations and ordinary user-owned Firestore data.
class ProductivityService {
  ProductivityService(this.firestore);
  final FirebaseFirestore firestore;
  DocumentReference<Map<String, dynamic>> user(String uid) =>
      firestore.collection('users').doc(uid);

  static List<PlanSuggestion> suggest({
    required List<TaskModel> tasks,
    required DateTime today,
    required int availableMinutes,
    Map<String, Map<String, dynamic>> metadata = const {},
  }) {
    final done = tasks
        .where((task) => task.done)
        .map((task) => task.id)
        .toSet();
    final candidates = <PlanSuggestion>[];
    for (final task in tasks) {
      if (task.done ||
          ['someday', 'reference', 'waiting'].contains(task.listType)) {
        continue;
      }
      final data = metadata[task.id] ?? {};
      final dependencies =
          (data['dependsOn'] as List?)?.whereType<String>() ?? [];
      if (dependencies.any((id) => !done.contains(id))) continue;
      final due = task.deadline ?? task.date;
      if (calendarDay(due).isAfter(calendarDay(today))) continue;
      final late =
          calendarDaysBetween(calendarDay(due), calendarDay(today)) > 0;
      final minutes = ((data['estimatedMinutes'] as num?)?.toInt() ?? 25).clamp(
        5,
        480,
      );
      final priority = switch (task.priority) {
        TaskPriority.high => 30,
        TaskPriority.medium => 20,
        TaskPriority.low => 10,
      };
      candidates.add(
        PlanSuggestion(
          task,
          minutes,
          late ? 'overdue' : 'due_today',
          priority + (late ? 40 : 20),
        ),
      );
    }
    candidates.sort((a, b) {
      final score = b.score.compareTo(a.score);
      return score != 0 ? score : a.task.id.compareTo(b.task.id);
    });
    var remaining = availableMinutes.clamp(0, 1440);
    final result = <PlanSuggestion>[];
    for (final candidate in candidates) {
      if (candidate.minutes > remaining || result.length >= 3) continue;
      result.add(candidate);
      remaining -= candidate.minutes;
    }
    return result;
  }

  Future<void> setMyDay(String uid, DateTime date, List<String> taskIds) async {
    if (taskIds.length > 3 || taskIds.toSet().length != taskIds.length) {
      throw ArgumentError('Choose up to three priorities');
    }
    await user(
      uid,
    ).collection('dailyPlans').doc(CompletionLedger.dateKey(date)).set({
      'date': CompletionLedger.dateKey(date),
      'taskIds': taskIds,
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
  }

  Future<void> linkTask({
    required String uid,
    required String taskId,
    required List<String> dependencies,
    String? goalId,
    String? milestoneTitle,
    int estimatedMinutes = 25,
    List<Map<String, String>> attachments = const [],
  }) async {
    if (dependencies.contains(taskId) ||
        dependencies.length > 5 ||
        dependencies.toSet().length != dependencies.length ||
        estimatedMinutes < 1 ||
        estimatedMinutes > 1440 ||
        attachments.length > 10) {
      throw ArgumentError('Invalid task links');
    }
    for (final attachment in attachments) {
      final value = attachment['value'] ?? '';
      if (!['url', 'local'].contains(attachment['kind']) ||
          value.isEmpty ||
          value.length > 2048) {
        throw ArgumentError('Invalid attachment');
      }
      if (attachment['kind'] == 'url' &&
          !['http', 'https'].contains(Uri.tryParse(value)?.scheme)) {
        throw ArgumentError('Only HTTP/HTTPS links are allowed');
      }
    }
    final tasks = user(uid).collection('tasks');
    // Every dependency edit also increments the same revision document, preventing
    // concurrent A->B / B->A edits from each validating against an old graph.
    final revision = user(
      uid,
    ).collection('productivity').doc('dependencyGraph');
    await firestore.runTransaction((transaction) async {
      final currentRevision = await transaction.get(revision);
      final target = await transaction.get(tasks.doc(taskId));
      if (!target.exists || target.data()?['locked'] == true) {
        throw StateError('Task cannot be edited');
      }
      DocumentReference<Map<String, dynamic>>? goalRef;
      Map<String, dynamic>? goalData;
      if (goalId != null) {
        goalRef = user(uid).collection('goals').doc(goalId);
        final goal = await transaction.get(goalRef);
        if (!goal.exists || goal.data()?['deletionPending'] == true) {
          throw StateError('Goal no longer exists');
        }
        goalData = goal.data()!;
        if (milestoneTitle != null &&
            !(goalData['milestones'] as List? ?? []).any(
              (m) => (m as Map)['title'] == milestoneTitle,
            )) {
          throw StateError('Milestone no longer exists');
        }
      }
      final previousGoalId = target.data()?['goalId'] as String?;
      DocumentReference<Map<String, dynamic>>? previousGoalRef;
      Map<String, dynamic>? previousGoalData;
      if (previousGoalId != null && previousGoalId != goalId) {
        previousGoalRef = user(uid).collection('goals').doc(previousGoalId);
        previousGoalData = (await transaction.get(previousGoalRef)).data();
      }
      final snapshot = await tasks.get();
      final graph = {
        for (final doc in snapshot.docs)
          doc.id:
              (doc.data()['dependsOn'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              <String>[],
      };
      if (dependencies.any((id) => !graph.containsKey(id))) {
        throw StateError('A dependency no longer exists');
      }
      graph[taskId] = dependencies;
      final visited = <String>{};
      final stack = <String>{};
      bool visit(String id) {
        if (stack.contains(id)) return false;
        if (visited.contains(id)) return true;
        stack.add(id);
        for (final next in graph[id] ?? <String>[]) {
          if (!visit(next)) return false;
        }
        stack.remove(id);
        visited.add(id);
        return true;
      }

      if (!visit(taskId)) throw StateError('Dependencies would form a cycle');
      Map<String, dynamic>? linkedGoalPatch, previousGoalPatch;
      if (goalRef != null && goalData != null) {
        final links = Map<String, dynamic>.from(
          goalData['taskLinks'] as Map? ?? {},
        )..[taskId] = milestoneTitle;
        linkedGoalPatch = await deriveGoalTasks(
          transaction: transaction,
          user: user(uid),
          goal: goalData,
          links: links,
          overrideId: taskId,
          overrideData: target.data(),
        );
      }
      if (previousGoalRef != null && previousGoalData != null) {
        final links = Map<String, dynamic>.from(
          previousGoalData['taskLinks'] as Map? ?? {},
        )..remove(taskId);
        previousGoalPatch = await deriveGoalTasks(
          transaction: transaction,
          user: user(uid),
          goal: previousGoalData,
          links: links,
        );
      }
      if (goalRef != null && goalData != null) {
        final links = Map<String, dynamic>.from(
          goalData['taskLinks'] as Map? ?? {},
        );
        if (links.length >= 50 && !links.containsKey(taskId)) {
          throw StateError('A goal supports up to 50 linked tasks');
        }
        links[taskId] = milestoneTitle;
        transaction.update(goalRef, linkedGoalPatch!);
      }
      if (previousGoalRef != null && previousGoalPatch != null) {
        transaction.update(previousGoalRef, previousGoalPatch);
      }
      transaction.update(tasks.doc(taskId), {
        'dependsOn': dependencies,
        'goalId': goalId,
        'milestoneTitle': milestoneTitle,
        'estimatedMinutes': estimatedMinutes,
        'attachments': attachments,
        'schemaVersion': 2,
      });
      transaction.set(revision, {
        'version':
            ((currentRevision.data()?['version'] as num?)?.toInt() ?? 0) + 1,
      });
    });
  }

  Future<void> checkDependencies(String uid, String taskId) async {
    final task = await user(uid).collection('tasks').doc(taskId).get();
    for (final id
        in (task.data()?['dependsOn'] as List?)?.whereType<String>() ??
            <String>[]) {
      final dependency = await user(uid).collection('tasks').doc(id).get();
      if (dependency.data()?['done'] != true) {
        throw StateError('Complete the prerequisite tasks first');
      }
    }
  }

  Future<String> saveRecurrence(
    String uid,
    TaskModel template,
    String frequency, {
    DateTime? end,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    int intervalDays = 1,
    bool afterCompletion = false,
  }) async {
    if (!['daily', 'weekly', 'monthly', 'interval'].contains(frequency) ||
        intervalDays < 1 ||
        intervalDays > 365 ||
        template.isGroupAssigned ||
        weekdays.isEmpty ||
        weekdays.length > 7 ||
        weekdays.toSet().length != weekdays.length ||
        (end != null &&
            calendarDay(end).isBefore(calendarDay(template.date))) ||
        weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Invalid recurrence');
    }
    final source = user(uid).collection('tasks').doc(template.id);
    final fresh = await source.get();
    if (!fresh.exists) throw StateError('Task no longer exists');
    final id =
        fresh.data()?['recurrenceId'] as String? ?? 'task_${template.id}';
    final data = template.toMap()
      ..remove('id')
      ..remove('doneAt')
      ..remove('groupAssignmentId')
      ..remove('assignedByGroupId');
    data['subtasks'] = [
      for (final item in template.subtasks) {...item.toMap(), 'done': false},
    ];
    data['currentCount'] = 0;
    await firestore.runTransaction((transaction) async {
      final original = await transaction.get(source);
      if (!original.exists ||
          original.data()?['locked'] == true ||
          original.data()?['deletionPending'] == true) {
        throw StateError('Task cannot be repeated');
      }
      transaction.set(user(uid).collection('taskRecurrences').doc(id), {
        'template': data,
        'originalTaskId': template.id,
        'frequency': frequency,
        'start': Timestamp.fromDate(calendarDay(template.date)),
        'end': end == null ? null : Timestamp.fromDate(calendarDay(end)),
        'weekdays': weekdays,
        'intervalDays': intervalDays,
        'afterCompletion': afterCompletion,
        if (afterCompletion) 'lastTaskId': template.id,
        'enabled': true,
        'schemaVersion': 1,
      });
      transaction.update(source, {
        'recurrenceId': id,
        'occurrenceDate': CompletionLedger.dateKey(template.date),
      });
    });
    return id;
  }

  /// One dated instance per occurrence. A retry cannot duplicate the task.
  Future<int> materialize(String uid, DateTime today) async {
    final definitions = await user(
      uid,
    ).collection('taskRecurrences').where('enabled', isEqualTo: true).get();
    var created = 0;
    for (final definition in definitions.docs) {
      final data = definition.data();
      final start = calendarDay((data['start'] as Timestamp).toDate());
      final end = (data['end'] as Timestamp?)?.toDate();
      final afterCompletion = data['afterCompletion'] == true;
      final interval = ((data['intervalDays'] as num?)?.toInt() ?? 1).clamp(
        1,
        365,
      );
      final candidates = [calendarDay(today), calendarDay(today, 1)];
      String? completionAnchorId;
      if (afterCompletion) {
        completionAnchorId =
            data['lastTaskId'] as String? ?? data['originalTaskId'] as String?;
        final skippedDate = (data['skippedAnchorDate'] as Timestamp?)?.toDate();
        if (skippedDate != null) {
          candidates
            ..clear()
            ..add(calendarDay(skippedDate, interval));
        } else if (completionAnchorId != null) {
          final anchor = await user(
            uid,
          ).collection('tasks').doc(completionAnchorId).get();
          final completed = (anchor.data()?['doneAt'] as Timestamp?)?.toDate();
          if (anchor.data()?['done'] != true || completed == null) continue;
          candidates
            ..clear()
            ..add(calendarDay(completed, interval));
        } else {
          continue;
        }
      }
      // Create today and tomorrow, rather than an unbounded backlog of missed dates.
      for (final date in candidates) {
        if (date.isBefore(start) ||
            (end != null && date.isAfter(calendarDay(end)))) {
          continue;
        }
        final frequency = data['frequency'];
        final occurs = afterCompletion || frequency == 'interval'
            ? afterCompletion ||
                  calendarDaysBetween(start, date) % interval == 0
            : frequency == 'daily'
            ? (data['weekdays'] as List).contains(date.weekday)
            : frequency == 'weekly'
            ? date.weekday == start.weekday
            : date.day ==
                  start.day.clamp(
                    1,
                    DateTime(date.year, date.month + 1, 0).day,
                  );
        if (!occurs) continue;
        final key = '${definition.id}_${CompletionLedger.dateKey(date)}';
        final original = data['originalTaskId'] as String?;
        final target = user(uid)
            .collection('tasks')
            .doc(
              date == start && original != null ? original : 'recurrence_$key',
            );
        final skipped = user(uid).collection('recurrenceSkips').doc(key);
        final seed = Map<String, dynamic>.from(data['template'] as Map);
        final deadline = (seed['deadline'] as Timestamp?)?.toDate();
        if (deadline != null) {
          seed['deadline'] = Timestamp.fromDate(
            calendarDay(
              date,
              calendarDaysBetween(start, calendarDay(deadline)),
            ),
          );
        }
        final added = await firestore.runTransaction((transaction) async {
          final previous = await transaction.get(target);
          final skip = await transaction.get(skipped);
          if (afterCompletion) {
            final current = await transaction.get(definition.reference);
            if (current.data()?['lastTaskId'] != data['lastTaskId'] ||
                current.data()?['skippedAnchorDate'] !=
                    data['skippedAnchorDate'] ||
                current.data()?['enabled'] != true) {
              return false;
            }
            if (data['skippedAnchorDate'] == null &&
                completionAnchorId != null) {
              final anchor = await transaction.get(
                user(uid).collection('tasks').doc(completionAnchorId),
              );
              final completed = (anchor.data()?['doneAt'] as Timestamp?)
                  ?.toDate();
              if (anchor.data()?['done'] != true ||
                  completed == null ||
                  calendarDay(completed, interval) != date) {
                return false;
              }
            }
          }
          if (skip.exists) return false;
          if (previous.exists) {
            if (date == start &&
                original != null &&
                previous.data()?['recurrenceId'] == null) {
              transaction.update(target, {
                'recurrenceId': definition.id,
                'occurrenceDate': CompletionLedger.dateKey(date),
              });
            }
            return false;
          }
          transaction.set(target, {
            ...seed,
            'id': target.id,
            'done': false,
            'doneAt': null,
            'currentCount': 0,
            'date': Timestamp.fromDate(date),
            'createdAt': FieldValue.serverTimestamp(),
            'recurrenceId': definition.id,
            'occurrenceDate': CompletionLedger.dateKey(date),
            'schemaVersion': 2,
          });
          if (afterCompletion) {
            transaction.update(definition.reference, {
              'lastTaskId': target.id,
              'skippedAnchorDate': null,
            });
          }
          return true;
        });
        if (added) created++;
      }
    }
    return created;
  }

  Future<void> skipOccurrence(String uid, String taskId) async {
    final target = user(uid).collection('tasks').doc(taskId);
    await firestore.runTransaction((transaction) async {
      final previous = await transaction.get(target);
      if (!previous.exists || previous.data()?['recurrenceId'] == null) {
        throw StateError('Not a recurring occurrence');
      }
      final data = previous.data()!;
      if (data['done'] == true) {
        throw StateError('Completed occurrences are kept in history');
      }
      final definition = user(
        uid,
      ).collection('taskRecurrences').doc(data['recurrenceId'] as String);
      final series = await transaction.get(definition);
      if (series.data()?['afterCompletion'] == true &&
          series.data()?['lastTaskId'] == taskId) {
        transaction.update(definition, {'skippedAnchorDate': data['date']});
      }
      transaction.set(
        user(uid)
            .collection('recurrenceSkips')
            .doc('${data['recurrenceId']}_${data['occurrenceDate']}'),
        {
          'date': data['occurrenceDate'],
          'recurrenceId': data['recurrenceId'],
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      transaction.delete(target);
    });
  }

  Future<void> saveTemplate(
    String uid,
    String name,
    List<TaskModel> tasks,
  ) async {
    if (name.trim().isEmpty ||
        tasks.isEmpty ||
        tasks.length > 50 ||
        tasks.any((task) => task.isGroupAssigned)) {
      throw ArgumentError('Invalid template');
    }
    await user(uid).collection('taskTemplates').add({
      'name': name.trim(),
      'items': tasks
          .map(
            (task) => {
              'title': task.title,
              'notes': task.notes,
              'categoryId': task.categoryId,
              'priority': task.priority.name,
              'subtasks': task.subtasks
                  .map((item) => {...item.toMap(), 'done': false})
                  .toList(),
            },
          )
          .toList(),
      'schemaVersion': 1,
    });
  }

  Future<void> useTemplate(
    String uid,
    String templateId,
    String requestId,
    DateTime date,
  ) async {
    final template = await user(
      uid,
    ).collection('taskTemplates').doc(templateId).get();
    if (!template.exists) throw StateError('Template no longer exists');
    final items = List<Map<String, dynamic>>.from(
      template.data()!['items'] as List,
    );
    if (items.length > 50) throw StateError('Template is too large');
    await firestore.runTransaction((transaction) async {
      final job = user(uid).collection('templateRuns').doc(requestId);
      final previous = await transaction.get(job);
      if (previous.exists) return;
      final projectCopies = <String, String>{};
      for (var index = 0; index < items.length; index++) {
        if (items[index]['collection'] == 'paraProjects') {
          projectCopies[items[index]['originalId'] as String] =
              'template_${requestId}_$index';
        }
      }
      for (var index = 0; index < items.length; index++) {
        final collection = items[index]['collection'] as String? ?? 'tasks';
        if (!['tasks', 'habits', 'paraProjects'].contains(collection)) {
          throw StateError('Invalid template source');
        }
        final data = Map<String, dynamic>.from(
          items[index]['data'] as Map? ?? items[index],
        );
        final originalDate = (data['date'] as Timestamp?)?.toDate();
        final deadline = (data['deadline'] as Timestamp?)?.toDate();
        if (deadline != null) {
          data['deadline'] = Timestamp.fromDate(
            calendarDay(
              date,
              originalDate == null
                  ? 0
                  : calendarDaysBetween(
                      calendarDay(originalDate),
                      calendarDay(deadline),
                    ).clamp(0, 3650),
            ),
          );
        }
        if (data['projectId'] is String &&
            projectCopies.containsKey(data['projectId'])) {
          data['projectId'] = projectCopies[data['projectId']];
        }
        final target = user(
          uid,
        ).collection(collection).doc('template_${requestId}_$index');
        transaction.set(target, {
          ...data,
          'id': target.id,
          if (collection == 'tasks')
            'date': Timestamp.fromDate(calendarDay(date)),
          if (collection == 'tasks') 'done': false,
          if (collection == 'tasks') 'doneAt': null,
          if (collection == 'habits') 'days': List.filled(7, false),
          if (collection == 'habits') 'streak': 0,
          if (collection == 'habits') 'baseStreak': 0,
          if (collection == 'habits') 'lastCompletedDate': null,
          if (collection == 'habits')
            'lastResetDate': Timestamp.fromDate(calendarDay(date)),
          if (collection == 'habits') 'totalCount': 0,
          if (collection == 'habits') 'isCompleted': false,
          if (collection == 'habits' || collection == 'tasks')
            'currentCount': 0,
          if (collection == 'paraProjects') 'archived': false,
          'createdAt': FieldValue.serverTimestamp(),
          'templateId': templateId,
        });
      }
      transaction.set(job, {
        'templateId': templateId,
        'count': items.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static String fingerprint(Map<String, dynamic> value) =>
      CompletionLedger.eventKey(jsonEncode(value));

  Future<void> saveWorkspaceTemplate(
    String uid,
    String name,
    List<Map<String, dynamic>> records,
  ) async {
    if (name.trim().isEmpty ||
        name.length > 100 ||
        records.isEmpty ||
        records.length > 50) {
      throw ArgumentError('Invalid template');
    }
    final items = <Map<String, dynamic>>[];
    for (final record in records) {
      final collection = record['collection'];
      if (!['tasks', 'habits', 'paraProjects'].contains(collection)) {
        throw ArgumentError('Invalid source');
      }
      final data = Map<String, dynamic>.from(record['data'] as Map);
      if (data['locked'] == true || data['assignedByGroupId'] != null) {
        throw StateError('Group assignments cannot be copied');
      }
      for (final field in [
        'id',
        'createdAt',
        'updatedAt',
        'doneAt',
        'groupAssignmentId',
        'assignedByGroupId',
        'assignedByName',
        'deletionPending',
        'goalId',
        'milestoneTitle',
        'dependsOn',
        'recurrenceId',
        'occurrenceDate',
      ]) {
        data.remove(field);
      }
      if (data['subtasks'] is List) {
        data['subtasks'] = [
          for (final item in data['subtasks'] as List)
            {...Map<String, dynamic>.from(item as Map), 'done': false},
        ];
      }
      items.add({
        'collection': collection,
        'originalId': record['id'],
        'data': data,
      });
    }
    if (items.toString().length > 500000) {
      throw ArgumentError('Template exceeds the local size limit');
    }
    await user(uid).collection('taskTemplates').add({
      'name': name.trim(),
      'items': items,
      'schemaVersion': 2,
    });
  }
}
