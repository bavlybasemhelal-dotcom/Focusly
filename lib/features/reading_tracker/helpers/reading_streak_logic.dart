/// Pure helper calculating consecutive daily reading streaks.
///
/// Contains NO side effects or external dependencies for 100% deterministic testability.
class ReadingStreakLogic {
  /// Computes the current reading streak in days from a collection of [readingDates].
  ///
  /// Leniency Rule:
  /// - If the user has already logged reading today, the streak counts today + all consecutive preceding days.
  /// - If the user has NOT yet logged reading today, but logged yesterday, the streak is NOT broken and counts yesterday + consecutive preceding days.
  /// - If neither today nor yesterday has a reading entry, the streak is 0.
  static int calculateReadingStreak(
    List<DateTime> readingDates, [
    DateTime? now,
  ]) {
    if (readingDates.isEmpty) return 0;

    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Normalize dates to unique midnight dates
    final Set<DateTime> normalizedDates = {};
    for (final d in readingDates) {
      normalizedDates.add(DateTime(d.year, d.month, d.day));
    }

    if (normalizedDates.isEmpty) return 0;

    // Check if streak starts from today or yesterday
    DateTime checkDate;
    if (normalizedDates.contains(today)) {
      checkDate = today;
    } else if (normalizedDates.contains(yesterday)) {
      checkDate = yesterday;
    } else {
      // Neither today nor yesterday was logged
      return 0;
    }

    int streak = 0;
    while (normalizedDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }
}
