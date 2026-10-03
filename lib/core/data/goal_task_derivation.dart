import 'package:cloud_firestore/cloud_firestore.dart';

Future<Map<String, dynamic>> deriveGoalTasks({
  required Transaction transaction,
  required DocumentReference<Map<String, dynamic>> user,
  required Map<String, dynamic> goal,
  required Map<String, dynamic> links,
  String? overrideId,
  Map<String, dynamic>? overrideData,
}) async {
  final completed = <String, bool>{};
  if (links.length > 50) throw StateError('Too many linked tasks');
  for (final id in links.keys) {
    final data = id == overrideId
        ? overrideData
        : (await transaction.get(user.collection('tasks').doc(id))).data();
    completed[id] = data?['done'] == true;
  }
  final manual = (goal['manualMilestones'] as List? ?? [])
      .whereType<String>()
      .toSet();
  final milestones = [
    for (final item in goal['milestones'] as List? ?? [])
      Map<String, dynamic>.from(item as Map),
  ];
  for (final milestone in milestones) {
    if (manual.contains(milestone['title'])) continue;
    final ids = links.entries
        .where((entry) => entry.value == milestone['title'])
        .map((entry) => entry.key)
        .toList();
    if (ids.isNotEmpty) {
      milestone['done'] = ids.every((id) => completed[id] == true);
    } else if ((goal['taskLinks'] as Map? ?? {}).values.contains(
      milestone['title'],
    )) {
      milestone['done'] = false;
    }
  }
  return {
    'taskLinks': links,
    'milestones': milestones,
    'progressSource': 'linkedTasks',
    if (milestones.isNotEmpty)
      'progress':
          (milestones.where((item) => item['done'] == true).length /
                  milestones.length *
                  100)
              .round(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
