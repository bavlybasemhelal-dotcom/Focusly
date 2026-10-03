import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../progress/constants/xp_constants.dart';
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
    return _booksCollection(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => BookModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Streams all reading activity logs for [uid] ordered by date descending.
  Stream<List<ReadingLogModel>> streamReadingLogs(String uid) {
    return _readingLogsCollection(
      uid,
    ).orderBy('date', descending: true).snapshots().map((snapshot) {
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

      final batch = _firestore.batch();
      batch.set(docRef, book.toMap());
      if (book.currentPage > 0) {
        batch.set(
          _readingLogsCollection(uid).doc('${book.id}_${book.currentPage}'),
          {
            'bookId': book.id,
            'pagesRead': book.currentPage,
            'endPage': book.currentPage,
            'date': Timestamp.now(),
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();

      // If initial currentPage > 0, log reading activity and award initial XP
      if (currentPage > 0) {
        // XP hook
        if (book.isFinished) {
          await ProgressService(firestore: _firestore).awardXp(
            XpConstants.readingBookFinished,
            source: 'Finished book: "${book.title}"',
            sourceType: 'reading_finished',
            uid: uid,
            sourceId: book.id,
            eventId: 'reading_finished_${book.id}',
            context: context != null && context.mounted ? context : null,
            ref: ref,
          );
        } else {
          await ProgressService(firestore: _firestore).awardXp(
            XpConstants.readingProgress,
            source: 'Reading progress: "${book.title}" ($currentPage pages)',
            sourceType: 'reading',
            uid: uid,
            sourceId: book.id,
            eventId: 'reading_${book.id}_${book.currentPage}',
            context: context != null && context.mounted ? context : null,
            ref: ref,
          );
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
      if (newBook.title.trim().isEmpty ||
          newBook.totalPages < 1 ||
          newBook.currentPage < 0 ||
          newBook.currentPage > newBook.totalPages) {
        throw ArgumentError('Invalid reading progress');
      }
      final target = _booksCollection(uid).doc(newBook.id);
      final result = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(target);
        if (!snapshot.exists || snapshot.data()?['deletionPending'] == true) {
          throw StateError('Book no longer exists');
        }
        final fresh = BookModel.fromMap(snapshot.data()!, newBook.id);
        final newData = newBook.toMap(), original = oldBook.toMap();
        final patch = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        for (final field in newData.keys) {
          if (['id', 'createdAt', 'updatedAt'].contains(field)) continue;
          if (newData[field].toString() != original[field].toString()) {
            patch[field] = newData[field];
          }
        }
        final page = patch['currentPage'] as int? ?? fresh.currentPage;
        final total = patch['totalPages'] as int? ?? fresh.totalPages;
        if (page < fresh.currentPage || total < page) {
          throw StateError('Reading progress changed. Reopen the form.');
        }
        final delta = page - fresh.currentPage;
        if (page >= total) {
          patch['status'] = 'done';
          patch['finishDate'] = fresh.finishDate == null
              ? Timestamp.now()
              : Timestamp.fromDate(fresh.finishDate!);
        }
        final logRef = _readingLogsCollection(uid).doc('${newBook.id}_$page');
        final previousLog = await transaction.get(logRef);
        transaction.update(target, patch);
        if (delta > 0 && !previousLog.exists) {
          transaction.set(logRef, {
            'bookId': newBook.id,
            'pagesRead': delta,
            'endPage': page,
            'date': Timestamp.now(),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        return (page, delta, patch['status'] == 'done' && !fresh.isFinished);
      });
      if (result.$2 > 0 || newBook.currentPage > oldBook.currentPage) {
        final finished =
            result.$3 || (newBook.isFinished && !oldBook.isFinished);
        await ProgressService(firestore: _firestore).awardXp(
          finished
              ? XpConstants.readingBookFinished
              : XpConstants.readingProgress,
          source: finished ? 'Finished book' : 'Reading progress',
          sourceType: finished ? 'reading_finished' : 'reading',
          uid: uid,
          sourceId: newBook.id,
          eventId: finished
              ? 'reading_finished_${newBook.id}'
              : 'reading_${newBook.id}_${result.$1}',
          context: context != null && context.mounted ? context : null,
          ref: ref,
        );
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
      context: context != null && context.mounted ? context : null,
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
  Future<bool> deleteBook({required String uid, required String bookId}) async {
    try {
      await _booksCollection(uid).doc(bookId).update({'deletionPending': true});
      while (true) {
        final logs = await _readingLogsCollection(
          uid,
        ).where('bookId', isEqualTo: bookId).limit(150).get();
        if (logs.docs.isEmpty) break;
        final batch = _firestore.batch();
        for (final doc in logs.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
      await _booksCollection(uid).doc(bookId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting book: $e');
      return false;
    }
  }
}
