import 'package:cloud_firestore/cloud_firestore.dart';

/// Bounded requests preserve complete results without Firestore batch overflow.
Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> readFirestorePages(
  Query<Map<String, dynamic>> source, {
  int pageSize = 150,
}) async {
  final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
  DocumentSnapshot<Map<String, dynamic>>? cursor;
  while (true) {
    var query = source.orderBy(FieldPath.documentId).limit(pageSize);
    if (cursor != null) query = query.startAfterDocument(cursor);
    final page = await query.get();
    result.addAll(page.docs);
    if (page.docs.length < pageSize) return result;
    cursor = page.docs.last;
  }
}
