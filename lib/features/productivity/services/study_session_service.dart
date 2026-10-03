import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/completion_ledger.dart';
import '../../../core/data/calendar_clock.dart';
import '../../tasks/models/task_model.dart';

class StudySessionService {
  StudySessionService(this.firestore);
  final FirebaseFirestore firestore;
  static int nextStep(String collection, Map<String, dynamic> data) {
    if (collection == 'books') {
      return (data['currentPage'] as num?)?.toInt() ?? 0;
    }
    if (collection == 'courses') {
      return (data['completedLessons'] as num?)?.toInt() ?? 0;
    }
    final steps = (data['steps'] as List? ?? []).whereType<Map>();
    final day =
        steps.where((step) => step['completed'] != true).firstOrNull?['day']
            as num?;
    return day == null ? -1 : day.toInt() - 1;
  }

  Future<TaskModel> plan({
    required String uid,
    required String collection,
    required String sourceId,
    required DateTime date,
    String? goalId,
    int minutes = 25,
  }) async {
    if (!['books', 'courses', 'learningPaths'].contains(collection) ||
        minutes < 5 ||
        minutes > 480) {
      throw ArgumentError('Invalid learning session');
    }
    final user = firestore.collection('users').doc(uid),
        source = user.collection(collection).doc(sourceId);
    return firestore.runTransaction((tx) async {
      final snapshot = await tx.get(source);
      if (!snapshot.exists || snapshot.data()?['deletionPending'] == true) {
        throw StateError('Learning source no longer exists');
      }
      final data = snapshot.data()!, step = nextStep(collection, data);
      if (step < 0 ||
          (collection == 'books' &&
              step >= ((data['totalPages'] as num?)?.toInt() ?? 0)) ||
          (collection == 'courses' &&
              step >= ((data['totalLessons'] as num?)?.toInt() ?? 0))) {
        throw StateError('This source is complete');
      }
      final id =
          'study_${CompletionLedger.eventKey('$collection:$sourceId:$step:${goalId ?? ''}:${CompletionLedger.dateKey(date)}')}';
      final target = user.collection('tasks').doc(id),
          old = await tx.get(target);
      if (old.exists) return TaskModel.fromMap(old.data()!, id);
      if (goalId != null) {
        final goal = await tx.get(user.collection('goals').doc(goalId));
        if (!goal.exists || goal.data()?['deletionPending'] == true) {
          throw StateError('Goal unavailable');
        }
      }
      final task = TaskModel(
        id: id,
        title: '${data['title']} • ${step + 1}',
        categoryId: 'study',
        date: calendarDay(date),
        createdAt: DateTime.now(),
        learningSource: {
          'collection': collection,
          'id': sourceId,
          'step': step,
        },
      );
      tx.set(target, {
        ...task.toMap(),
        'goalId': goalId,
        'estimatedMinutes': minutes,
      });
      return task;
    });
  }
}
