import '../models/nutrition_log_model.dart';

/// Container representing a single day in the 7-day visual timeline.
class NutritionDayCell {
  final DateTime date;
  final int dayOffset; // 6 for 6-days-ago, 0 for today
  final int? rating; // 1-5 or null if not logged
  final String emoji; // 😊, 🙂, 😐, 😕, 😞, or ⚪
  final String formattedMonthDay; // "MM-DD"
  final NutritionLogModel? log;

  const NutritionDayCell({
    required this.date,
    required this.dayOffset,
    required this.rating,
    required this.emoji,
    required this.formattedMonthDay,
    this.log,
  });
}

/// Container for weekly comparison averages.
class NutritionWeeklyComparison {
  final double? thisWeekAvg; // Average rating for past 7 days (last 0..6 days)
  final double?
  lastWeekAvg; // Average rating for previous 7 days (last 7..13 days)

  const NutritionWeeklyComparison({
    required this.thisWeekAvg,
    required this.lastWeekAvg,
  });
}

/// Pure helper functions for date formatting, 7-day timeline computation,
/// and week-over-week average ratings.
class NutritionLogHelpers {
  /// Formats a DateTime into a standardized date key `YYYY-MM-DD`.
  static String formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Formats a DateTime into `MM-DD` for the 7-day timeline cell labels.
  static String formatMonthDay(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  /// Normalizes a DateTime to midnight (00:00:00.000) for exact calendar day comparisons.
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Computes the 7-day timeline cells (left = 6 days ago / oldest, right = today).
  static List<NutritionDayCell> compute7DayTimeline(
    List<NutritionLogModel> logs, [
    DateTime? now,
  ]) {
    final current = now ?? DateTime.now();
    final today = toDateOnly(current);
    final List<NutritionDayCell> result = [];

    // Map existing logs by date key for O(1) lookup
    final Map<String, NutritionLogModel> logsByDateKey = {};
    for (final log in logs) {
      final key = formatDateKey(log.date);
      logsByDateKey[key] = log;
    }

    // Loop from 6 days ago (i = 6) down to today (i = 0)
    for (int i = 6; i >= 0; i--) {
      final targetDate = today.subtract(Duration(days: i));
      final dateKey = formatDateKey(targetDate);
      final log = logsByDateKey[dateKey];

      final rating = log?.rating;
      final emoji = NutritionLogModel.getEmojiForRating(rating);
      final monthDay = formatMonthDay(targetDate);

      result.add(
        NutritionDayCell(
          date: targetDate,
          dayOffset: i,
          rating: rating,
          emoji: emoji,
          formattedMonthDay: monthDay,
          log: log,
        ),
      );
    }

    return result;
  }

  /// Shared pure helper function to calculate the average rating over any window of days ago.
  ///
  /// [minDaysAgo]: inclusive start of window (e.g. 0 for today)
  /// [maxDaysAgo]: inclusive end of window (e.g. 6 for 6 days ago)
  static double? calculateWeeklyAverage(
    List<NutritionLogModel> logs, {
    required int minDaysAgo,
    required int maxDaysAgo,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = toDateOnly(current);

    final windowStart = today.subtract(Duration(days: maxDaysAgo));
    final windowEnd = today.subtract(Duration(days: minDaysAgo));

    int sumRatings = 0;
    int count = 0;

    for (final log in logs) {
      final logDate = toDateOnly(log.date);
      // Check if logDate falls in [windowStart, windowEnd] inclusive
      if ((logDate.isAtSameMomentAs(windowStart) ||
              logDate.isAfter(windowStart)) &&
          (logDate.isAtSameMomentAs(windowEnd) ||
              logDate.isBefore(windowEnd))) {
        sumRatings += log.rating;
        count++;
      }
    }

    if (count == 0) return null;
    return sumRatings / count;
  }

  /// Computes week-over-week comparison (This Week = last 7 days 0..6, Last Week = 8..14 days ago 7..13).
  static NutritionWeeklyComparison computeWeeklyComparison(
    List<NutritionLogModel> logs, [
    DateTime? now,
  ]) {
    final thisWeek = calculateWeeklyAverage(
      logs,
      minDaysAgo: 0,
      maxDaysAgo: 6,
      now: now,
    );

    final lastWeek = calculateWeeklyAverage(
      logs,
      minDaysAgo: 7,
      maxDaysAgo: 13,
      now: now,
    );

    return NutritionWeeklyComparison(
      thisWeekAvg: thisWeek,
      lastWeekAvg: lastWeek,
    );
  }

  /// Formats an average rating to 1 decimal place or returns "−" if null.
  static String formatAverage(double? avg) {
    if (avg == null) return '−';
    return avg.toStringAsFixed(1);
  }
}
