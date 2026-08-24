import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../progress/services/progress_service.dart';
import '../models/book_model.dart';
import '../models/reading_log_model.dart';

/// Service managing Firestore operations for the Reading Tracker feature.
///
/// Documents are isolated per user under:
/// - `users/{uid}/books/{bookId}`
/// - `users/{uid}/readingLogs/{logId}`
class ReadingService {
  final FirebaseFirestore _firestore;

  ReadingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _booksCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('books');
  }

  CollectionReference<Map<String, dynamic>> _readingLogsCollection(String uid) {
    return _firestore.collection('users').doc(uid).collection('readingLogs');
  }

  /// Streams all books for [uid] ordered by updatedAt descending.
  Stream<List<BookModel>> streamBooks(String uid) {
    return _booksCollection(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BookModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Streams all reading activity logs for [uid] ordered by date descending.
  Stream<List<ReadingLogModel>> streamReadingLogs(String uid) {
    return _readingLogsCollection(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReadingLogModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Creates a new book document.
  Future<String?> addBook({
    required String uid,
    required String title,
    required String author,
    int totalPages = 200,
    int currentPage = 0,
    String status = 'reading',
    int coverColor = 0xFF2E6FF2,
    String? coverUrl,
    DateTime? startDate,
    DateTime? finishDate,
    int? rating,
    String notes = '',
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final docRef = _booksCollection(uid).doc();
      final now = DateTime.now();

      final book = BookModel(
        id: docRef.id,
        title: title.trim(),
        author: author.trim(),
        totalPages: totalPages > 0 ? totalPages : 200,
        currentPage: currentPage.clamp(0, totalPages),
        status: status,
        coverColor: coverColor,
        coverUrl: coverUrl,
        startDate: startDate ?? (status != 'wishlist' ? now : null),
        finishDate: finishDate,
        rating: rating,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(book.toMap());

      // If initial currentPage > 0, log reading activity and award initial XP
      if (currentPage > 0) {
        await logReadingActivity(
          uid: uid,
          bookId: docRef.id,
          pagesRead: currentPage,
          date: now,
        );

        // XP hook
        if (book.isFinished) {
          await ProgressService().awardXp(50, context: context, ref: ref);
        } else {
          await ProgressService().awardXp(15, context: context, ref: ref);
        }
      }

      return docRef.id;
    } catch (e) {
      debugPrint('Error adding book: $e');
      return null;
    }
  }

  /// Updates an existing book and triggers XP awards if page progress occurred.
  Future<bool> updateBook({
    required String uid,
    required BookModel newBook,
    required BookModel oldBook,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    try {
      final now = DateTime.now();
      var updated = newBook.copyWith(updatedAt: now);

      // Auto-complete if currentPage reaches totalPages
      if (updated.currentPage >= updated.totalPages && updated.status != 'done') {
        updated = updated.copyWith(
          status: 'done',
          finishDate: updated.finishDate ?? now,
          rating: updated.rating ?? 5,
        );
      }

      await _booksCollection(uid).doc(updated.id).update(updated.toMap());

      // XP hook: Check if progress was made
      if (updated.currentPage > oldBook.currentPage) {
        final pagesRead = updated.currentPage - oldBook.currentPage;
        await logReadingActivity(
          uid: uid,
          bookId: updated.id,
          pagesRead: pagesRead,
          date: now,
        );

        // Tiered XP: +50 if brought to done for the first time, +15 for standard progress
        if (!oldBook.isFinished && updated.isFinished) {
          await ProgressService().awardXp(50, context: context, ref: ref);
        } else {
          await ProgressService().awardXp(15, context: context, ref: ref);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error updating book: $e');
      return false;
    }
  }

  /// Quick page update method (used by quick-update dialog).
  Future<bool> quickUpdatePageProgress({
    required String uid,
    required BookModel book,
    required int newPage,
    BuildContext? context,
    WidgetRef? ref,
  }) async {
    final clampedPage = newPage.clamp(book.currentPage, book.totalPages);
    final isFinishing = clampedPage >= book.totalPages;
    final now = DateTime.now();

    final updated = book.copyWith(
      currentPage: clampedPage,
      status: isFinishing ? 'done' : book.status,
      finishDate: isFinishing ? (book.finishDate ?? now) : book.finishDate,
      rating: isFinishing ? (book.rating ?? 5) : book.rating,
      updatedAt: now,
    );

    return updateBook(
      uid: uid,
      newBook: updated,
      oldBook: book,
      context: context,
      ref: ref,
    );
  }

  /// Logs a reading activity entry.
  Future<void> logReadingActivity({
    required String uid,
    required String bookId,
    required int pagesRead,
    DateTime? date,
  }) async {
    if (pagesRead <= 0) return;
    try {
      final docRef = _readingLogsCollection(uid).doc();
      final now = DateTime.now();
      final log = ReadingLogModel(
        id: docRef.id,
        bookId: bookId,
        pagesRead: pagesRead,
        date: date ?? now,
        createdAt: now,
      );
      await docRef.set(log.toMap());
    } catch (e) {
      debugPrint('Error logging reading activity: $e');
    }
  }

  /// Deletes a specific book.
  Future<bool> deleteBook({
    required String uid,
    required String bookId,
  }) async {
    try {
      await _booksCollection(uid).doc(bookId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting book: $e');
      return false;
    }
  }
}
