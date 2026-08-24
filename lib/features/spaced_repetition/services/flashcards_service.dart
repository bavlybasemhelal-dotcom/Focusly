import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/flashcard_model.dart';

/// Service managing Firestore operations for the Spaced Repetition (Flashcards) feature.
///
/// Documents are isolated per user under `users/{uid}/flashcards/{cardId}`.
class FlashcardsService {
  final FirebaseFirestore _firestore;

  FlashcardsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _flashcardsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('flashcards');
  }

  /// Streams all flashcards for [uid] ordered by createdAt descending.
  Stream<List<FlashcardModel>> streamFlashcards(String uid) {
    return _flashcardsCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => FlashcardModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Adds a new flashcard with initial SM-2 parameters.
  Future<String?> addFlashcard({
    required String uid,
    required String front,
    required String back,
  }) async {
    try {
      final docRef = _flashcardsCollection(uid).doc();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final card = FlashcardModel(
        id: docRef.id,
        front: front.trim(),
        back: back.trim(),
        interval: 0,
        repetitions: 0,
        easeFactor: 2.5,
        dueDate: todayStr,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(card.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error adding flashcard: $e');
      return null;
    }
  }

  /// Updates front/back text of an existing flashcard without resetting SM-2 scheduling progress.
  Future<bool> updateFlashcardContent({
    required String uid,
    required FlashcardModel currentCard,
    required String newFront,
    required String newBack,
  }) async {
    try {
      final now = DateTime.now();
      final updated = currentCard.copyWith(
        front: newFront.trim(),
        back: newBack.trim(),
        updatedAt: now,
      );

      await _flashcardsCollection(uid).doc(updated.id).update(updated.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating flashcard: $e');
      return false;
    }
  }

  /// Persists updated SM-2 scheduling parameters immediately after a review.
  Future<bool> saveReviewProgress({
    required String uid,
    required FlashcardModel updatedCard,
  }) async {
    try {
      await _flashcardsCollection(uid).doc(updatedCard.id).update(updatedCard.toMap());
      return true;
    } catch (e) {
      debugPrint('Error saving flashcard review progress: $e');
      return false;
    }
  }

  /// Deletes a flashcard.
  Future<bool> deleteFlashcard({
    required String uid,
    required String cardId,
  }) async {
    try {
      await _flashcardsCollection(uid).doc(cardId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting flashcard: $e');
      return false;
    }
  }
}
