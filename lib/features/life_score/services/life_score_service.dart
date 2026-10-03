import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/life_score_model.dart';

/// Firestore persistence service for Weekly Life Score snapshots.
///
/// Fully isolated per user under `users/{uid}/lifeScoreLog/{weekOf}`.
class LifeScoreService {
  final FirebaseFirestore _firestore;

  LifeScoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _lifeScoreCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('lifeScoreLog');
  }

  /// Streams all historical life score logs for the authenticated user.
  Stream<List<LifeScoreModel>> streamLifeScoreLogs(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _lifeScoreCollection(
      uid,
    ).orderBy('weekOf', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return LifeScoreModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Gets a specific week's stored snapshot.
  Future<LifeScoreModel?> getSnapshot(String uid, String weekOf) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _lifeScoreCollection(uid).doc(weekOf).get();
      if (!doc.exists || doc.data() == null) return null;
      return LifeScoreModel.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// Saves or updates a week's life score snapshot.
  Future<void> saveSnapshot(String uid, LifeScoreModel model) async {
    if (uid.isEmpty) return;
    await _lifeScoreCollection(
      uid,
    ).doc(model.weekOf).set(model.toMap(), SetOptions(merge: true));
  }
}
