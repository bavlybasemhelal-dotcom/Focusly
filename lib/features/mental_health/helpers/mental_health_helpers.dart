import '../models/mental_log_model.dart';

/// Represents a Sunday-to-Saturday calendar week boundary range.
class WeekRange {
  final DateTime startDate; // Sunday
  final DateTime endDate; // Saturday

  const WeekRange({
    required this.startDate,
    required this.endDate,
  });

  String get formattedStartDate => MentalHealthHelpers.formatDateKey(startDate);
  String get formattedEndDate => MentalHealthHelpers.formatDateKey(endDate);
}

/// Result container for personalized tip calculation based on the lowest-scoring dimension.
class LowestDimensionTip {
  final String dimensionKey; // e.g. 'dimension_calm'
  final String tipKey; // e.g. 'tip_calm'
  final int score; // 1 to 10

  const LowestDimensionTip({
    required this.dimensionKey,
    required this.tipKey,
    required this.score,
  });
}

/// Movement direction enum for Today vs Yesterday comparison.
enum ComparisonDirection {
  improved,
  declined,
  same,
  noYesterday,
}

/// Single dimension comparison result container.
class DimensionComparison {
  final String dimensionKey;
  final int todayValue;
  final int? yesterdayValue;
  final ComparisonDirection direction;

  const DimensionComparison({
    required this.dimensionKey,
    required this.todayValue,
    this.yesterdayValue,
    required this.direction,
  });
}

/// Full 5-dimension comparison container.
class TodayVsYesterdayComparison {
  final bool hasYesterday;
  final List<DimensionComparison> comparisons;

  const TodayVsYesterdayComparison({
    required this.hasYesterday,
    required this.comparisons,
  });
}

/// Pure helper functions for date keys, week boundaries, weekly averages,
/// lowest dimension tip generation, and today-vs-yesterday comparison.
class MentalHealthHelpers {
  /// Formats date to standardized date key `YYYY-MM-DD`.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Normalizes date to midnight.
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Computes the Sunday-start to Saturday week range for [date].
  /// Matches JS Sunday=0 convention where Sunday starts the week.
  static WeekRange getWeekBoundaries(DateTime date) {
    final dateOnly = toDateOnly(date);
    // Sunday in Dart has weekday == 7 (7 % 7 = 0)
    // Monday has weekday == 1 (1 % 7 = 1)
    // Saturday has weekday == 6 (6 % 7 = 6)
    final diff = dateOnly.weekday % 7;
    final sunday = dateOnly.subtract(Duration(days: diff));
    final saturday = sunday.add(const Duration(days: 6));

    return WeekRange(
      startDate: sunday,
      endDate: saturday,
    );
  }

  /// Computes the weekly average for all entries in the week containing [selectedDate].
  /// Returns null if zero entries exist in that week.
  static MentalLogModel? computeWeeklyAverage(
    List<MentalLogModel> allLogs,
    DateTime selectedDate,
  ) {
    final week = getWeekBoundaries(selectedDate);
    final weekStart = week.startDate;
    final weekEnd = week.endDate;

    final weekLogs = allLogs.where((log) {
      final logDate = toDateOnly(log.date);
      return (logDate.isAtSameMomentAs(weekStart) || logDate.isAfter(weekStart)) &&
          (logDate.isAtSameMomentAs(weekEnd) || logDate.isBefore(weekEnd));
    }).toList();

    if (weekLogs.isEmpty) return null;

    final count = weekLogs.length;
    int sumAnxiety = 0;
    int sumHappiness = 0;
    int sumSocial = 0;
    int sumSatisfaction = 0;
    int sumBalance = 0;

    for (final l in weekLogs) {
      sumAnxiety += l.anxiety;
      sumHappiness += l.happiness;
      sumSocial += l.socialEnergy;
      sumSatisfaction += l.selfSatisfaction;
      sumBalance += l.balance;
    }

    final avgAnxiety = (sumAnxiety / count).round().clamp(1, 10);
    final avgHappiness = (sumHappiness / count).round().clamp(1, 10);
    final avgSocial = (sumSocial / count).round().clamp(1, 10);
    final avgSatisfaction = (sumSatisfaction / count).round().clamp(1, 10);
    final avgBalance = (sumBalance / count).round().clamp(1, 10);

    final now = DateTime.now();
    return MentalLogModel(
      id: 'weekly_avg_${week.formattedStartDate}',
      weekOf: formatDateKey(selectedDate),
      anxiety: avgAnxiety,
      happiness: avgHappiness,
      socialEnergy: avgSocial,
      selfSatisfaction: avgSatisfaction,
      balance: avgBalance,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Finds the lowest-scoring dimension and returns its personalized tip.
  ///
  /// Scoring:
  /// - Calm: `11 - anxiety` (inverted)
  /// - Happiness: raw value
  /// - Social Energy: raw value
  /// - Self Satisfaction: raw value
  /// - Life Balance: raw value
  static LowestDimensionTip? findLowestDimension({
    MentalLogModel? currentDisplayLog,
    required List<MentalLogModel> allLogs,
  }) {
    MentalLogModel? target = currentDisplayLog;

    // Fallback: If current display log is null, use the most recent entry overall
    if (target == null && allLogs.isNotEmpty) {
      final sorted = List<MentalLogModel>.from(allLogs)
        ..sort((a, b) => b.date.compareTo(a.date));
      target = sorted.first;
    }

    if (target == null) return null;

    final scores = [
      {
        'key': 'dimension_calm',
        'tipKey': 'tip_calm',
        'score': target.calmScore,
      },
      {
        'key': 'dimension_happiness',
        'tipKey': 'tip_happiness',
        'score': target.happiness,
      },
      {
        'key': 'dimension_social_energy',
        'tipKey': 'tip_social_energy',
        'score': target.socialEnergy,
      },
      {
        'key': 'dimension_self_satisfaction',
        'tipKey': 'tip_self_satisfaction',
        'score': target.selfSatisfaction,
      },
      {
        'key': 'dimension_balance',
        'tipKey': 'tip_balance',
        'score': target.balance,
      },
    ];

    // Find entry with minimum score
    var lowest = scores.first;
    for (int i = 1; i < scores.length; i++) {
      if ((scores[i]['score'] as int) < (lowest['score'] as int)) {
        lowest = scores[i];
      }
    }

    return LowestDimensionTip(
      dimensionKey: lowest['key'] as String,
      tipKey: lowest['tipKey'] as String,
      score: lowest['score'] as int,
    );
  }

  /// Compares today's log vs yesterday's log across all 5 dimensions.
  ///
  /// IMPORTANT: Anxiety has inverted polarity for comparison!
  /// - Anxiety: Decrease = Improved, Increase = Declined
  /// - Other 4 dimensions: Increase = Improved, Decrease = Declined
  static TodayVsYesterdayComparison compareTodayVsYesterday({
    required MentalLogModel todayLog,
    MentalLogModel? yesterdayLog,
  }) {
    final hasYesterday = yesterdayLog != null;

    ComparisonDirection evaluateStandard(int today, int? yesterday) {
      if (yesterday == null) return ComparisonDirection.noYesterday;
      if (today > yesterday) return ComparisonDirection.improved;
      if (today < yesterday) return ComparisonDirection.declined;
      return ComparisonDirection.same;
    }

    ComparisonDirection evaluateAnxiety(int today, int? yesterday) {
      if (yesterday == null) return ComparisonDirection.noYesterday;
      // For anxiety, lower is better!
      if (today < yesterday) return ComparisonDirection.improved;
      if (today > yesterday) return ComparisonDirection.declined;
      return ComparisonDirection.same;
    }

    final comparisons = [
      DimensionComparison(
        dimensionKey: 'dimension_happiness',
        todayValue: todayLog.happiness,
        yesterdayValue: yesterdayLog?.happiness,
        direction: evaluateStandard(todayLog.happiness, yesterdayLog?.happiness),
      ),
      DimensionComparison(
        dimensionKey: 'dimension_anxiety',
        todayValue: todayLog.anxiety,
        yesterdayValue: yesterdayLog?.anxiety,
        direction: evaluateAnxiety(todayLog.anxiety, yesterdayLog?.anxiety),
      ),
      DimensionComparison(
        dimensionKey: 'dimension_social_energy',
        todayValue: todayLog.socialEnergy,
        yesterdayValue: yesterdayLog?.socialEnergy,
        direction: evaluateStandard(todayLog.socialEnergy, yesterdayLog?.socialEnergy),
      ),
      DimensionComparison(
        dimensionKey: 'dimension_self_satisfaction',
        todayValue: todayLog.selfSatisfaction,
        yesterdayValue: yesterdayLog?.selfSatisfaction,
        direction: evaluateStandard(todayLog.selfSatisfaction, yesterdayLog?.selfSatisfaction),
      ),
      DimensionComparison(
        dimensionKey: 'dimension_balance',
        todayValue: todayLog.balance,
        yesterdayValue: yesterdayLog?.balance,
        direction: evaluateStandard(todayLog.balance, yesterdayLog?.balance),
      ),
    ];

    return TodayVsYesterdayComparison(
      hasYesterday: hasYesterday,
      comparisons: comparisons,
    );
  }
}
