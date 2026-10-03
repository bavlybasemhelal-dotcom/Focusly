import 'package:cloud_firestore/cloud_firestore.dart';

class InboxConversionService {
  InboxConversionService(this.firestore);
  final FirebaseFirestore firestore;
  Future<String> convert({
    required String uid,
    required String inboxId,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    if (!['tasks', 'events'].contains(collection) ||
        uid.isEmpty ||
        inboxId.isEmpty) {
      throw ArgumentError('Invalid conversion');
    }
    final user = firestore.collection('users').doc(uid);
    final inbox = user.collection('inbox').doc(inboxId);
    final target = user.collection(collection).doc('inbox_$inboxId');
    return firestore.runTransaction((transaction) async {
      final source = await transaction.get(inbox);
      final existing = await transaction.get(target);
      if (collection == 'tasks' &&
          data['projectId'] is String &&
          (data['projectId'] as String).isNotEmpty) {
        final project = await transaction.get(
          user.collection('paraProjects').doc(data['projectId'] as String),
        );
        if (!project.exists || project.data()?['deletionPending'] == true) {
          throw StateError('Project no longer exists');
        }
      }
      if (!source.exists) throw StateError('Inbox item no longer exists');
      if (source.data()?['processed'] == true) {
        if (source.data()?['destination'] != collection || !existing.exists) {
          throw StateError('Inbox item already processed elsewhere');
        }
        return target.id;
      }
      if (!existing.exists) {
        transaction.set(target, {
          ...data,
          'id': target.id,
          'originInboxId': inboxId,
        });
      }
      transaction.update(inbox, {
        'processed': true,
        'destination': collection,
        'destinationId': target.id,
        'processedAt': FieldValue.serverTimestamp(),
      });
      return target.id;
    });
  }
}
