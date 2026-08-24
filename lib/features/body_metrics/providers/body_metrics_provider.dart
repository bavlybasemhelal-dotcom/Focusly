import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../helpers/body_metrics_helpers.dart';
import '../models/body_metric_model.dart';
import '../services/body_metrics_service.dart';

/// Provider exposing BodyMetricsService singleton.
final bodyMetricsServiceProvider = Provider<BodyMetricsService>((ref) {
  return BodyMetricsService();
});

/// Stream provider for all body metrics belonging to the authenticated user.
///
/// Strictly scoped to `users/{uid}/bodyMetrics`.
final bodyMetricsStreamProvider = StreamProvider<List<BodyMetricModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null || uid.isEmpty) return const Stream.empty();

  final service = ref.watch(bodyMetricsServiceProvider);
  return service.streamBodyMetrics(uid);
});

/// Derived provider: Latest readings container (weight, complete BP, pulse independently extracted).
final latestBodyReadingsProvider = Provider<LatestBodyReadings>((ref) {
  final logs = ref.watch(bodyMetricsStreamProvider).value ?? [];
  return BodyMetricsHelpers.computeLatestReadings(logs);
});

/// Derived provider: Chronological ascending points for Weight trend chart.
final weightSeriesProvider = Provider<List<ChartDataPoint>>((ref) {
  final logs = ref.watch(bodyMetricsStreamProvider).value ?? [];
  return BodyMetricsHelpers.extractWeightSeries(logs);
});

/// Derived provider: Chronological ascending points for Pulse trend chart.
final pulseSeriesProvider = Provider<List<ChartDataPoint>>((ref) {
  final logs = ref.watch(bodyMetricsStreamProvider).value ?? [];
  return BodyMetricsHelpers.extractPulseSeries(logs);
});

/// Derived provider: Chronological ascending points for Blood Pressure trend chart.
final bpSeriesProvider = Provider<BpChartSeries>((ref) {
  final logs = ref.watch(bodyMetricsStreamProvider).value ?? [];
  return BodyMetricsHelpers.extractBpSeries(logs);
});
