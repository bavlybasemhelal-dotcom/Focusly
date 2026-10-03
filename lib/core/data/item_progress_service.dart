import 'package:cloud_firestore/cloud_firestore.dart';
import 'completion_intents.dart';

/// Updates only progress fields and its group mirror in the same transaction.
class ItemProgressService {
  ItemProgressService(this.firestore);
  final FirebaseFirestore firestore;

  Future<Map<String, dynamic>> task({
    required String uid,
    required String id,
    required bool done,
    int? count,
  }) => _change(uid, 'tasks', id, (data) {
    final target = (data['targetCount'] as num?)?.toInt() ?? 1;
    final value = count ?? (data['currentCount'] as num?)?.toInt() ?? 0;
    if (value < 0 || value > target) throw ArgumentError('Invalid count');
    final completed = data['completionMode'] == 'count'
        ? value >= target
        : done;
    return {
      'done': completed,
      'currentCount': value,
      'doneAt': completed ? Timestamp.now() : null,
    };
  });

  Future<Map<String, dynamic>> habitCount({
    required String uid,
    required String id,
    required int delta,
  }) => _change(uid, 'habits', id, (data) {
    if (delta.abs() != 1 || data['completionMode'] != 'count') {
      throw ArgumentError('Invalid count operation');
    }
    final target = (data['targetCount'] as num?)?.toInt() ?? 1;
    final count = ((data['currentCount'] as num?)?.toInt() ?? 0) + delta;
    final bounded = count.clamp(0, target);
    return {'currentCount': bounded, 'isCompleted': bounded >= target};
  });

  Future<Map<String, dynamic>> _change(
    String uid,
    String collection,
    String id,
    Map<String, dynamic> Function(Map<String, dynamic>) patch,
  ) async {
    if (uid.isEmpty || id.isEmpty) throw ArgumentError('Missing item identity');
    final item = firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(id);
    final before = await item.get();
    if (before.exists &&
        collection == 'tasks' &&
        patch(before.data()!)['done'] == true) {
      await CompletionIntents.task(uid, id, before.data()!);
    }
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(item);
      if (!snapshot.exists) throw StateError('Item no longer exists');
      final data = snapshot.data()!;
      final changes = patch(data);
      final completed = collection == 'tasks' && changes['done'] == true;
      if (completed) {
        final dependencies =
            (data['dependsOn'] as List?)?.whereType<String>().toList() ??
            <String>[];
        if (dependencies.length > 5) {
          throw StateError('Too many prerequisite tasks');
        }
        for (final dependencyId in dependencies) {
          final dependency = await transaction.get(
            item.parent.doc(dependencyId),
          );
          if (dependency.data()?['done'] != true) {
            throw StateError('Complete the prerequisite tasks first');
          }
        }
      }
      final groupId = data['assignedByGroupId'] as String?;
      final assignmentId = data['groupAssignmentId'] as String?;
      DocumentReference<Map<String, dynamic>>? mirror;
      if (groupId != null && assignmentId != null) {
        final assignment = firestore
            .collection('groups')
            .doc(groupId)
            .collection('assignments')
            .doc(assignmentId);
        final parent = await transaction.get(assignment);
        if (!parent.exists) throw StateError('Assignment no longer exists');
        mirror = assignment.collection('completions').doc(uid);
        final previous = await transaction.get(mirror);
        if (previous.data()?['decision'] == 'rejected') {
          throw StateError('Accept the assignment before recording progress');
        }
      }
      final updated = {...data, ...changes};
      DocumentReference<Map<String, dynamic>>? goalRef;
      Map<String, dynamic>? goalPatch;
      final goalId = data['goalId'] as String?;
      final milestoneTitle = data['milestoneTitle'] as String?;
      if (collection == 'tasks' && goalId != null && milestoneTitle != null) {
        goalRef = firestore
            .collection('users')
            .doc(uid)
            .collection('goals')
            .doc(goalId);
        final goal = await transaction.get(goalRef);
        if (goal.exists) {
          final goalData = goal.data()!;
          final linked = Map<String, dynamic>.from(
            goalData['taskLinks'] as Map? ?? {},
          );
          final related = linked.entries
              .where((entry) => entry.value == milestoneTitle)
              .map((entry) => entry.key)
              .toList();
          var allDone = related.isNotEmpty;
          for (final relatedId in related) {
            final done = relatedId == id
                ? changes['done'] == true
                : (await transaction.get(
                        item.parent.doc(relatedId),
                      )).data()?['done'] ==
                      true;
            allDone = allDone && done;
          }
          final manual =
              (goalData['manualMilestones'] as List?)
                  ?.whereType<String>()
                  .toSet() ??
              <String>{};
          if (!manual.contains(milestoneTitle)) {
            final milestones = List<Map<String, dynamic>>.from(
              (goalData['milestones'] as List? ?? []).map(
                (value) => Map<String, dynamic>.from(value as Map),
              ),
            );
            for (final milestone in milestones) {
              if (milestone['title'] == milestoneTitle) {
                milestone['done'] = allDone;
              }
            }
            goalPatch = {
              'milestones': milestones,
              'progress': milestones.isEmpty
                  ? goalData['progress']
                  : (100 *
                            milestones.where((m) => m['done'] == true).length /
                            milestones.length)
                        .round(),
              'updatedAt': FieldValue.serverTimestamp(),
              'progressSource': 'linkedTasks',
            };
          }
        }
      }
      transaction.update(item, changes);
      if (goalRef != null && goalPatch != null) {
        transaction.update(goalRef, goalPatch);
      }
      if (mirror != null) {
        writeMirror(transaction, mirror, uid, id, collection, updated);
      }
      return updated;
    });
  }

  static void writeMirror(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> mirror,
    String uid,
    String id,
    String collection,
    Map<String, dynamic> data,
  ) {
    final done = collection == 'tasks'
        ? data['done'] == true
        : data['isCompleted'] == true;
    transaction.set(mirror, {
      'uid': uid,
      'itemId': id,
      'status': done ? 'done' : 'pending',
      'currentCount': data['completionMode'] == 'count'
          ? data['currentCount']
          : (done ? 1 : 0),
      'completedAt': done ? FieldValue.serverTimestamp() : null,
    }, SetOptions(merge: true));
  }
}
