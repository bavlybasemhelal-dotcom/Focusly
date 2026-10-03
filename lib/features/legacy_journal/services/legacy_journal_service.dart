import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/legacy_entry_model.dart';

/// Isolated Firestore service for managing Legacy Journal entries under `users/{uid}/legacyJournal`.
class LegacyJournalService {
  final FirebaseFirestore _firestore;

  LegacyJournalService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('legacyJournal');
  }

  /// Real-time stream of all legacy journal entries for a user, ordered by date descending
  Stream<List<LegacyEntryModel>> getEntriesStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection(uid).orderBy('date', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => LegacyEntryModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Adds a new legacy journal entry and returns the generated document ID
  Future<String> addEntry(String uid, LegacyEntryModel entry) async {
    final docRef = await _collection(uid).add(entry.toMap());
    return docRef.id;
  }

  /// Updates an existing legacy journal entry
  Future<void> updateEntry(String uid, LegacyEntryModel entry) async {
    await _collection(uid).doc(entry.id).update(entry.toMap());
  }

  /// Deletes a legacy journal entry
  Future<void> deleteEntry(String uid, String entryId) async {
    await _collection(uid).doc(entryId).delete();
  }
}
