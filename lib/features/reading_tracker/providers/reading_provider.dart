import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/reading_streak_logic.dart';
import '../models/book_model.dart';
import '../models/reading_log_model.dart';
import '../services/reading_service.dart';

/// Provider for ReadingService singleton.
final readingServiceProvider = Provider<ReadingService>((ref) {
  return ReadingService();
});

/// Stream provider for all books belonging to the authenticated user.
final booksStreamProvider = StreamProvider<List<BookModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(readingServiceProvider);
  return service.streamBooks(uid);
});

/// Stream provider for reading activity logs (used for streak computation).
final readingLogsStreamProvider = StreamProvider<List<ReadingLogModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final service = ref.watch(readingServiceProvider);
  return service.streamReadingLogs(uid);
});

/// Derived provider for currently reading & paused books shelf.
final readingShelfBooksProvider = Provider<List<BookModel>>((ref) {
  final books = ref.watch(booksStreamProvider).value ?? [];
  return books.where((b) => b.isReadingShelf).toList();
});

/// Derived provider for wishlist shelf books.
final wishlistShelfBooksProvider = Provider<List<BookModel>>((ref) {
  final books = ref.watch(booksStreamProvider).value ?? [];
  return books.where((b) => b.isWishlist).toList();
});

/// Derived provider for finished books shelf.
final finishedShelfBooksProvider = Provider<List<BookModel>>((ref) {
  final books = ref.watch(booksStreamProvider).value ?? [];
  return books.where((b) => b.isFinished).toList();
});

/// Derived provider calculating the active daily reading streak.
final readingStreakProvider = Provider<int>((ref) {
  final logs = ref.watch(readingLogsStreamProvider).value ?? [];
  final dates = logs.map((l) => l.date).toList();
  return ReadingStreakLogic.calculateReadingStreak(dates);
});

/// Reading stats aggregate data class.
class ReadingStatsData {
  final int booksFinished;
  final int currentlyReading;
  final int streakDays;
  final int totalPagesRead;
  final int totalPossiblePages;

  const ReadingStatsData({
    required this.booksFinished,
    required this.currentlyReading,
    required this.streakDays,
    required this.totalPagesRead,
    required this.totalPossiblePages,
  });

  int get overallProgressPercent {
    if (totalPossiblePages <= 0) return 0;
    return (totalPagesRead / totalPossiblePages * 100).round().clamp(0, 100);
  }
}

/// Derived provider computing overall reading statistics.
final readingStatsProvider = Provider<ReadingStatsData>((ref) {
  final books = ref.watch(booksStreamProvider).value ?? [];
  final streak = ref.watch(readingStreakProvider);

  int finished = 0;
  int reading = 0;
  int pagesRead = 0;
  int totalPages = 0;

  for (final book in books) {
    if (book.isFinished) {
      finished++;
    } else if (book.isReadingShelf) {
      reading++;
    }

    if (!book.isWishlist) {
      pagesRead += book.currentPage;
      totalPages += book.totalPages;
    }
  }

  return ReadingStatsData(
    booksFinished: finished,
    currentlyReading: reading,
    streakDays: streak,
    totalPagesRead: pagesRead,
    totalPossiblePages: totalPages,
  );
});
