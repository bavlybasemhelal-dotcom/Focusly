import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/data/firestore_paging.dart';

/// Each challenge score increment references one immutable group completion.
/// Retry keys prevent replay, and completion dates cannot be replaced by live totals.
class ChallengeEventsService {
  ChallengeEventsService(this.firestore);
  final FirebaseFirestore firestore;

  Future<void> syncParticipant({
    required String groupId,
    required String challengeId,
    required String uid,
  }) async {
    final group = firestore.collection('groups').doc(groupId);
    final challenge = group.collection('challenges').doc(challengeId);
    final definition = await challenge.get();
    if (!definition.exists || definition.data()?['status'] != 'active') return;
    final start = definition.data()!['startDate'] as Timestamp;
    final end = definition.data()!['endDate'] as Timestamp;
    final type = definition.data()!['type'];
    if (type != 'tasks' && type != 'habits') return;
    final events = await readFirestorePages(
      group
          .collection('xpEvents')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .where('createdAt', isLessThanOrEqualTo: end)
          .orderBy('createdAt'),
    );
    for (final event in events) {
      final data = event.data();
      if (data['challengeEligible'] == false ||
          data['uid'] != uid ||
          (type == 'tasks' && data['sourceType'] != 'task') ||
          (type == 'habits' &&
              !['habit', 'habit_count'].contains(data['sourceType']))) {
        continue;
      }
      final participant = challenge.collection('participants').doc(uid);
      final claim = challenge.collection('scoreEvents').doc(event.id);
      await firestore.runTransaction((transaction) async {
        final fresh = await transaction.get(challenge);
        final member = await transaction.get(participant);
        final previous = await transaction.get(claim);
        if (previous.exists ||
            !member.exists ||
            fresh.data()?['status'] != 'active') {
          return;
        }
        final joined = member.data()!['joinedAt'] as Timestamp;
        if ((data['createdAt'] as Timestamp).compareTo(joined) < 0) return;
        transaction.set(claim, {
          'uid': uid,
          'eventId': data['eventId'],
          'groupEventId': event.id,
        });
        transaction.update(participant, {
          'score': ((member.data()?['score'] as num?)?.toInt() ?? 0) + 1,
          'lastScoreEventId': event.id,
        });
      });
    }
  }
}
