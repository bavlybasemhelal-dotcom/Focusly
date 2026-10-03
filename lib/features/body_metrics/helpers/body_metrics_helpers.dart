import '../models/body_metric_model.dart';

/// Single plotted point on a trend line chart.
class ChartDataPoint {
  final DateTime date;
  final double value;
  final String formattedDate; // "MM-DD"
  final String formattedValue;

  const ChartDataPoint({
    required this.date,
    required this.value,
    required this.formattedDate,
    required this.formattedValue,
  });
}

/// Dual-series container for Blood Pressure trend chart (Systolic & Diastolic).
class BpChartSeries {
  final List<ChartDataPoint> systolicPoints;
  final List<ChartDataPoint> diastolicPoints;

  const BpChartSeries({
    required this.systolicPoints,
    required this.diastolicPoints,
  });

  bool get hasEnoughPoints =>
      systolicPoints.length >= 2 && diastolicPoints.length >= 2;
}

/// Container representing the most recent available readings for each metric independently.
class LatestBodyReadings {
  final double? latestWeight;
  final DateTime? weightDate;
  final int? latestSystolic;
  final int? latestDiastolic;
  final DateTime? bpDate;
  final int? latestPulse;
  final DateTime? pulseDate;

  const LatestBodyReadings({
    this.latestWeight,
    this.weightDate,
    this.latestSystolic,
    this.latestDiastolic,
    this.bpDate,
    this.latestPulse,
    this.pulseDate,
  });

  bool get hasWeight => latestWeight != null;
  bool get hasBp => latestSystolic != null && latestDiastolic != null;
  bool get hasPulse => latestPulse != null;
}

/// Pure helper functions for extracting latest values, series points, and date formatting.
class BodyMetricsHelpers {
  /// Formats date to `YYYY-MM-DD`.
  static String formatDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats date to `MM-DD`.
  static String formatMonthDay(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$m-$d';
  }

  /// Normalizes date to midnight.
  static DateTime toDateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Computes the latest available value per metric independently by inspecting
  /// entries sorted by date descending.
  static LatestBodyReadings computeLatestReadings(List<BodyMetricModel> logs) {
    if (logs.isEmpty) {
      return const LatestBodyReadings();
    }

    // Sort descending by date
    final sorted = List<BodyMetricModel>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    double? weight;
    DateTime? weightDate;
    int? systolic;
    int? diastolic;
    DateTime? bpDate;
    int? pulse;
    DateTime? pulseDate;

    for (final log in sorted) {
      if (weight == null && log.hasWeight) {
        weight = log.weight;
        weightDate = log.date;
      }
      if (systolic == null && diastolic == null && log.hasCompleteBp) {
        systolic = log.bpSystolic;
        diastolic = log.bpDiastolic;
        bpDate = log.date;
      }
      if (pulse == null && log.hasPulse) {
        pulse = log.pulse;
        pulseDate = log.date;
      }

      // If all 3 metrics are found, short-circuit
      if (weight != null && systolic != null && pulse != null) {
        break;
      }
    }

    return LatestBodyReadings(
      latestWeight: weight,
      weightDate: weightDate,
      latestSystolic: systolic,
      latestDiastolic: diastolic,
      bpDate: bpDate,
      latestPulse: pulse,
      pulseDate: pulseDate,
    );
  }

  /// Extracts chronological ascending data points for the Weight trend line chart.
  static List<ChartDataPoint> extractWeightSeries(List<BodyMetricModel> logs) {
    final validLogs = logs.where((l) => l.hasWeight).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return validLogs.map((l) {
      final val = l.weight!;
      final str = val % 1 == 0
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return ChartDataPoint(
        date: l.date,
        value: val,
        formattedDate: formatMonthDay(l.date),
        formattedValue: str,
      );
    }).toList();
  }

  /// Extracts chronological ascending data points for the Pulse trend line chart.
  static List<ChartDataPoint> extractPulseSeries(List<BodyMetricModel> logs) {
    final validLogs = logs.where((l) => l.hasPulse).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return validLogs.map((l) {
      final val = l.pulse!.toDouble();
      return ChartDataPoint(
        date: l.date,
        value: val,
        formattedDate: formatMonthDay(l.date),
        formattedValue: l.pulse.toString(),
      );
    }).toList();
  }

  /// Extracts chronological ascending dual-series points for Blood Pressure chart.
  static BpChartSeries extractBpSeries(List<BodyMetricModel> logs) {
    final validLogs = logs.where((l) => l.hasCompleteBp).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final systolicPoints = <ChartDataPoint>[];
    final diastolicPoints = <ChartDataPoint>[];

    for (final l in validLogs) {
      final monthDay = formatMonthDay(l.date);

      systolicPoints.add(
        ChartDataPoint(
          date: l.date,
          value: l.bpSystolic!.toDouble(),
          formattedDate: monthDay,
          formattedValue: l.bpSystolic.toString(),
        ),
      );

      diastolicPoints.add(
        ChartDataPoint(
          date: l.date,
          value: l.bpDiastolic!.toDouble(),
          formattedDate: monthDay,
          formattedValue: l.bpDiastolic.toString(),
        ),
      );
    }

    return BpChartSeries(
      systolicPoints: systolicPoints,
      diastolicPoints: diastolicPoints,
    );
  }
}
