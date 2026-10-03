import 'package:cloud_firestore/cloud_firestore.dart';

/// Every interaction mutation updates affected contact dates atomically.
class ContactHistoryService {
  ContactHistoryService(this.firestore);
  final FirebaseFirestore firestore;
  Future<void> mutate(
    String uid,
    String id,
    Map<String, dynamic>? replacement, {
    bool mustExist = false,
  }) async {
    final user = firestore.collection('users').doc(uid);
    final logs = user.collection('relationshipLogs');
    final target = logs.doc(id);
    await firestore.runTransaction((transaction) async {
      final previous = await transaction.get(target);
      if (mustExist && !previous.exists) {
        throw StateError('Interaction no longer exists');
      }
      final affected = <String>{
        if (previous.data()?['contactId'] is String)
          previous.data()!['contactId'] as String,
        if (replacement != null) replacement['contactId'] as String,
      };
      final contacts = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final contactId in affected) {
        contacts[contactId] = await transaction.get(
          user.collection('contacts').doc(contactId),
        );
      }
      if (replacement != null &&
          (contacts[replacement['contactId']]?.exists != true ||
              contacts[replacement['contactId']]?.data()?['deletionPending'] ==
                  true)) {
        throw StateError('Contact no longer exists');
      }
      // A concurrent interaction also changes its contact, forcing a retry with fresh history.
      final dates = <String, DateTime?>{};
      for (final contactId in affected) {
        final history = await logs
            .where('contactId', isEqualTo: contactId)
            .get();
        DateTime? latest;
        for (final doc in history.docs) {
          if (doc.id == id) continue;
          final value = doc.data()['date'];
          if (value is Timestamp &&
              (latest == null || value.toDate().isAfter(latest))) {
            latest = value.toDate();
          }
        }
        if (replacement?['contactId'] == contactId) {
          final date = (replacement!['date'] as Timestamp).toDate();
          if (latest == null || date.isAfter(latest)) latest = date;
        }
        dates[contactId] = latest;
      }
      if (replacement == null) {
        transaction.delete(target);
      } else {
        transaction.set(target, replacement);
      }
      for (final contactId in affected) {
        if (!contacts[contactId]!.exists) continue;
        transaction.update(user.collection('contacts').doc(contactId), {
          'lastContact': dates[contactId] == null
              ? null
              : Timestamp.fromDate(dates[contactId]!),
          'hasContacted': dates[contactId] != null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
