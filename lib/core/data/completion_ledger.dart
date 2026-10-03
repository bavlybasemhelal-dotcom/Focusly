import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'pending_operations.dart';

/// Immutable reward events. The stable event ID is also the retry key.
/// An award is committed together with its total; there is no partial increment.
class CompletionLedger {
  CompletionLedger(this.firestore);
  final FirebaseFirestore firestore;
  static String eventKey(String key) =>
      sha256.convert(utf8.encode(key)).toString();

  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  static String weekKey(DateTime date) {
    final start = DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - DateTime.saturday + 7) % 7,
    );
    return dateKey(start);
  }

  Future<bool> award({
    required String uid,
    required String eventId,
    required String sourceId,
    required String sourceType,
    required int amount,
    required String label,
  }) async {
    if (uid.isEmpty ||
        eventId.isEmpty ||
        eventId.contains('/') ||
        sourceId.isEmpty ||
        amount < 0 ||
        amount > 50) {
      throw ArgumentError('Invalid completion event');
    }
    final user = firestore.collection('users').doc(uid);
    await PendingOperations.enqueue(uid, 'reward', eventId, {
      'sourceId': sourceId,
      'sourceType': sourceType,
      'amount': amount,
      'label': label,
    });
    final key = eventKey(eventId);
    final event = user.collection('completionEvents').doc(key);
    final progress = user.collection('stats').doc('progress');
    return firestore.runTransaction((transaction) async {
      final existing = await transaction.get(event);
      final previous = await transaction.get(progress);
      if (existing.exists) return false;
      final now = DateTime.now();
      final offset = now.timeZoneOffset.inMinutes;
      final start = DateTime.parse(weekKey(now));
      final data = {
        'uid': uid,
        'sourceId': sourceId,
        'sourceType': sourceType,
        'amount': amount,
        'source': label,
        'occurredOn': dateKey(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
        'week': weekKey(now),
        'timezoneMinutes': offset,
        'weekStartAt': Timestamp.fromDate(
          DateTime.utc(
            start.year,
            start.month,
            start.day,
          ).subtract(Duration(minutes: offset)),
        ),
        'sourceNumber': int.tryParse(eventId.split('_').last) ?? 0,
        'sourceDate': (sourceType == 'habit' || sourceType == 'flashcards')
            ? eventId.substring('${sourceType}_$sourceId'.length + 1)
            : '',
      };
      transaction.set(event, data);
      transaction.set(user.collection('xpLog').doc(key), data);
      transaction.set(progress, {
        'xp': ((previous.data()?['xp'] as num?)?.toInt() ?? 0) + amount,
        'lastEventId': key,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    });
  }

  /// Each group copy has its own retry key. New weeks never reset old totals.
  Future<void> syncGroups({
    required String uid,
    required String eventId,
  }) async {
    final user = firestore.collection('users').doc(uid);
    final key = eventKey(eventId);
    final source = await user.collection('completionEvents').doc(key).get();
    if (!source.exists) return;
    final data = source.data()!;
    if (data['schemaVersion'] == 0) {
      await PendingOperations.acknowledge(uid, 'reward', eventId);
      return;
    }
    final week = data['week'] as String;
    final profile = await user.get();
    final groups =
        (profile.data()?['groupIds'] as List?)?.whereType<String>() ??
        const <String>[];
    for (final groupId in groups) {
      final group = firestore.collection('groups').doc(groupId);
      final copy = group.collection('xpEvents').doc('${uid}_$key');
      final score = group.collection('weeklyScores').doc('${week}_$uid');
      await firestore.runTransaction((transaction) async {
        final member = await transaction.get(
          group.collection('members').doc(uid),
        );
        final previous = await transaction.get(copy);
        final total = await transaction.get(score);
        final joinedAt = member.data()?['joinedAt'];
        if (member.data()?['status'] != 'approved' ||
            previous.exists ||
            (joinedAt is Timestamp &&
                (data['createdAt'] as Timestamp).compareTo(joinedAt) < 0)) {
          return;
        }
        transaction.set(copy, {
          'uid': uid,
          'amount': data['amount'],
          'createdAt': data['createdAt'],
          'sourceType':
              ['task', 'habit', 'habit_count'].contains(data['sourceType'])
              ? data['sourceType']
              : 'activity',
          'challengeEligible':
              data['sourceType'] != 'habit' ||
              data['sourceDate'] == data['occurredOn'],
          'eventId': key,
          'week': week,
        });
        transaction.set(score, {
          'uid': uid,
          'week': week,
          'xp':
              ((total.data()?['xp'] as num?)?.toInt() ?? 0) +
              (data['amount'] as num).toInt(),
          'lastEventId': key,
        });
      });
    }
    await PendingOperations.acknowledge(uid, 'reward', eventId);
  }
}
