import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/completion_ledger.dart';
import '../../../core/data/goal_task_derivation.dart';

class TrashService {
  TrashService(this.firestore);
  final FirebaseFirestore firestore;
  static const supported = ['tasks', 'habits', 'inbox', 'paraResources'];
  Future<String> move(String uid, String collection, String id) async {
    if (!supported.contains(collection)) {
      throw ArgumentError('Unsupported trash item');
    }
    final source = firestore
        .collection('users')
        .doc(uid)
        .collection(collection)
        .doc(id);
    final key = CompletionLedger.eventKey('$collection/$id');
    final trash = firestore
        .collection('users')
        .doc(uid)
        .collection('trash')
        .doc(key);
    await firestore.runTransaction((transaction) async {
      final item = await transaction.get(source);
      if (!item.exists) return;
      if (item.data()?['locked'] == true) {
        throw StateError('Group assignments cannot be deleted');
      }
      DocumentReference<Map<String, dynamic>>? goalRef;
      Map<String, dynamic>? goalPatch;
      final goalId = item.data()?['goalId'] as String?;
      if (collection == 'tasks' && goalId != null) {
        final user = source.parent.parent!;
        goalRef = user.collection('goals').doc(goalId);
        final goal = await transaction.get(goalRef);
        if (goal.exists && goal.data()?['deletionPending'] != true) {
          final links = Map<String, dynamic>.from(
            goal.data()?['taskLinks'] as Map? ?? {},
          )..remove(id);
          goalPatch = await deriveGoalTasks(
            transaction: transaction,
            user: user,
            goal: goal.data()!,
            links: links,
          );
        }
      }
      transaction.set(trash, {
        'collection': collection,
        'originalId': id,
        'data': item.data(),
        'deletedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(source);
      if (goalRef != null && goalPatch != null) {
        transaction.update(goalRef, goalPatch);
      }
    });
    return key;
  }

  Future<void> restore(String uid, String key) async {
    final trash = firestore
        .collection('users')
        .doc(uid)
        .collection('trash')
        .doc(key);
    await firestore.runTransaction((transaction) async {
      final item = await transaction.get(trash);
      if (!item.exists) throw StateError('Trash item no longer exists');
      final data = item.data()!;
      if (!supported.contains(data['collection'])) {
        throw StateError('Invalid trash record');
      }
      final target = firestore
          .collection('users')
          .doc(uid)
          .collection(data['collection'] as String)
          .doc(data['originalId'] as String);
      final previous = await transaction.get(target);
      if (previous.exists) {
        throw StateError('An item with this ID already exists');
      }
      final restored = Map<String, dynamic>.from(data['data'] as Map);
      DocumentReference<Map<String, dynamic>>? goalRef;
      Map<String, dynamic>? goalPatch;
      final goalId = restored['goalId'] as String?,
          milestone = restored['milestoneTitle'] as String?;
      if (data['collection'] == 'tasks' &&
          goalId != null &&
          milestone != null) {
        final user = target.parent.parent!;
        goalRef = user.collection('goals').doc(goalId);
        final goal = await transaction.get(goalRef);
        if (goal.exists && goal.data()?['deletionPending'] != true) {
          final links = Map<String, dynamic>.from(
            goal.data()?['taskLinks'] as Map? ?? {},
          )..[target.id] = milestone;
          goalPatch = await deriveGoalTasks(
            transaction: transaction,
            user: user,
            goal: goal.data()!,
            links: links,
            overrideId: target.id,
            overrideData: restored,
          );
        } else {
          restored['goalId'] = null;
          restored['milestoneTitle'] = null;
        }
      }
      transaction.set(target, restored);
      transaction.delete(trash);
      if (goalRef != null && goalPatch != null) {
        transaction.update(goalRef, goalPatch);
      }
    });
  }

  Future<void> purge(String uid) async {
    final collection = firestore
        .collection('users')
        .doc(uid)
        .collection('trash');
    while (true) {
      final page = await collection.limit(150).get();
      if (page.docs.isEmpty) return;
      final batch = firestore.batch();
      for (final item in page.docs) {
        batch.delete(item.reference);
      }
      await batch.commit();
    }
  }
}
