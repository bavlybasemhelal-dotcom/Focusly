import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/life_area_assessment_model.dart';

/// Isolated Firestore service for managing Wheel of Life assessments under `users/{uid}/lifeAreas`.
class LifeAreasService {
  final FirebaseFirestore _firestore;

  LifeAreasService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return _firestore.collection('users').doc(uid).collection('lifeAreas');
  }

  /// Real-time stream of all Wheel of Life assessments for a user, ordered newest first
  Stream<List<LifeAreaAssessmentModel>> getAssessmentsStream(String uid) {
    if (uid.isEmpty) return Stream.value([]);

    return _collection(uid).orderBy('date', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => LifeAreaAssessmentModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Adds a new assessment and returns the generated document ID
  Future<String> addAssessment(
    String uid,
    LifeAreaAssessmentModel assessment,
  ) async {
    final docRef = await _collection(uid).add(assessment.toMap());
    return docRef.id;
  }

  /// Updates an existing assessment in Firestore
  Future<void> updateAssessment(
    String uid,
    LifeAreaAssessmentModel assessment,
  ) async {
    await _collection(uid).doc(assessment.id).update(assessment.toMap());
  }

  /// Deletes an assessment from Firestore
  Future<void> deleteAssessment(String uid, String assessmentId) async {
    await _collection(uid).doc(assessmentId).delete();
  }
}
