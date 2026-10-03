import 'dart:math';
import '../models/flashcard_model.dart';

/// Result container holding the updated scheduling metrics from an SM-2 calculation.
class Sm2Result {
  final int interval;
  final int repetitions;
  final double easeFactor;
  final String dueDate;
  final int points;

  const Sm2Result({
    required this.interval,
    required this.repetitions,
    required this.easeFactor,
    required this.dueDate,
    required this.points,
  });
}

/// Pure implementation of the SuperMemo 2 (SM-2) Spaced Repetition Algorithm.
///
/// Mathematical rules:
/// - Quality ratings:
///   - 1: Forgot (0 pts) -> resets interval to 1, repetitions to 0.
///   - 2: Hard (3 pts)
///   - 3: Good (5 pts)
///   - 4: Easy (10 pts)
/// - For successful recalls (quality 2, 3, 4):
///   - If repetitions == 0 -> interval = 1
///   - Else if repetitions == 1 -> interval = 3
///   - Else -> interval = round(interval * easeFactor)
///   - easeFactor = max(1.3, easeFactor + (0.1 - (4 - quality) * (0.08 + (4 - quality) * 0.02)))
///   - repetitions += 1
/// - New due date = today + interval days.
class Sm2Algorithm {
  /// Calculates the next review schedule for a flashcard using the SM-2 algorithm.
  static Sm2Result calculate({
    required int currentInterval,
    required int currentRepetitions,
    required double currentEaseFactor,
    required int quality, // 1: Forgot, 2: Hard, 3: Good, 4: Easy
    DateTime? currentDate,
  }) {
    if (quality < 1 || quality > 4) {
      throw RangeError.range(quality, 1, 4, 'quality');
    }
    if (currentInterval < 0 ||
        currentRepetitions < 0 ||
        !currentEaseFactor.isFinite ||
        currentEaseFactor < 1.3) {
      throw ArgumentError('Invalid review scheduling parameters');
    }
    final now = currentDate ?? DateTime.now();
    int newInterval;
    int newRepetitions;
    double newEaseFactor = currentEaseFactor;
    int points;

    switch (quality) {
      case 1: // Forgot
        points = 0;
        newInterval = 1;
        newRepetitions = 0;
        break;

      case 2: // Hard
        points = 3;
        if (currentRepetitions == 0) {
          newInterval = 1;
        } else if (currentRepetitions == 1) {
          newInterval = 3;
        } else {
          newInterval = (currentInterval * currentEaseFactor).round();
        }
        newEaseFactor = max(
          1.3,
          currentEaseFactor +
              (0.1 - (4 - quality) * (0.08 + (4 - quality) * 0.02)),
        );
        newRepetitions = currentRepetitions + 1;
        break;

      case 3: // Good
        points = 5;
        if (currentRepetitions == 0) {
          newInterval = 1;
        } else if (currentRepetitions == 1) {
          newInterval = 3;
        } else {
          newInterval = (currentInterval * currentEaseFactor).round();
        }
        newEaseFactor = max(
          1.3,
          currentEaseFactor +
              (0.1 - (4 - quality) * (0.08 + (4 - quality) * 0.02)),
        );
        newRepetitions = currentRepetitions + 1;
        break;

      case 4: // Easy
        points = 10;
        if (currentRepetitions == 0) {
          newInterval = 1;
        } else if (currentRepetitions == 1) {
          newInterval = 3;
        } else {
          newInterval = (currentInterval * currentEaseFactor).round();
        }
        newEaseFactor = max(
          1.3,
          currentEaseFactor +
              (0.1 - (4 - quality) * (0.08 + (4 - quality) * 0.02)),
        );
        newRepetitions = currentRepetitions + 1;
        break;
      default:
        throw ArgumentError.value(quality, 'quality');
    }

    final targetDate = DateTime(now.year, now.month, now.day + newInterval);
    final dueDateStr =
        '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';

    return Sm2Result(
      interval: newInterval,
      repetitions: newRepetitions,
      easeFactor: double.parse(newEaseFactor.toStringAsFixed(4)),
      dueDate: dueDateStr,
      points: points,
    );
  }

  /// Updates a [FlashcardModel] with SM-2 results after a review.
  static FlashcardModel applyReview(
    FlashcardModel card,
    int quality, [
    DateTime? currentDate,
  ]) {
    final result = calculate(
      currentInterval: card.interval,
      currentRepetitions: card.repetitions,
      currentEaseFactor: card.easeFactor,
      quality: quality,
      currentDate: currentDate,
    );

    return card.copyWith(
      interval: result.interval,
      repetitions: result.repetitions,
      easeFactor: result.easeFactor,
      dueDate: result.dueDate,
      updatedAt: currentDate ?? DateTime.now(),
    );
  }

  /// Performs an unbiased Fisher-Yates shuffle on a list of items.
  static List<T> fisherYatesShuffle<T>(List<T> items, [Random? rng]) {
    final random = rng ?? Random();
    final list = List<T>.from(items);
    for (int i = list.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
    return list;
  }
}
