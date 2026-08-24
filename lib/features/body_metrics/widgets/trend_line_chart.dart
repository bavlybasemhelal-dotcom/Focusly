import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../helpers/body_metrics_helpers.dart';

/// Single line series configuration for TrendLineChart.
class TrendSeries {
  final List<ChartDataPoint> points;
  final Color color;
  final String label;

  const TrendSeries({
    required this.points,
    required this.color,
    required this.label,
  });
}

/// Reusable Trend Line Chart widget supporting single or dual series,
/// with smooth line strokes, gradient area fills, data point markers,
/// subtle background gridlines, and date labels.
class TrendLineChart extends StatelessWidget {
  final List<TrendSeries> seriesList;
  final double height;
  final bool showLegend;
  final String? unit;

  const TrendLineChart({
    super.key,
    required this.seriesList,
    this.height = 140,
    this.showLegend = false,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.05);
    final textMutedColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : Colors.black.withValues(alpha: 0.45);

    // Calculate global min and max across all series
    double minVal = double.infinity;
    double maxVal = -double.infinity;
    int maxPointsCount = 0;

    for (final s in seriesList) {
      if (s.points.length > maxPointsCount) {
        maxPointsCount = s.points.length;
      }
      for (final p in s.points) {
        if (p.value < minVal) minVal = p.value;
        if (p.value > maxVal) maxVal = p.value;
      }
    }

    if (minVal == double.infinity || maxVal == -double.infinity) {
      return const SizedBox.shrink();
    }

    // Add padding to range so lines don't clip at top/bottom edges
    double range = maxVal - minVal;
    if (range <= 0) range = 10;
    final padding = range * 0.15;
    final chartMin = math.max(0.0, minVal - padding);
    final chartMax = maxVal + padding;

    // Pick representative X-axis date labels
    final firstSeries = seriesList.firstWhere(
      (s) => s.points.isNotEmpty,
      orElse: () => seriesList.first,
    );
    final dates = firstSeries.points.map((p) => p.formattedDate).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Optional Legend
        if (showLegend && seriesList.length > 1) ...[
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: seriesList.map((s) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Canvas Area with Min/Max Y-labels and Painter
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y-Axis Value Labels (Max at top, Min at bottom)
              SizedBox(
                width: 38,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      maxVal.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textMutedColor,
                      ),
                    ),
                    Text(
                      minVal.toInt().toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Main CustomPaint Canvas
              Expanded(
                child: CustomPaint(
                  painter: _TrendChartPainter(
                    seriesList: seriesList,
                    chartMin: chartMin,
                    chartMax: chartMax,
                    gridColor: gridColor,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // X-Axis Date Labels Row
        if (dates.length >= 2)
          Padding(
            padding: const EdgeInsets.only(left: 46.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dates.first,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: textMutedColor,
                  ),
                ),
                if (dates.length > 2)
                  Text(
                    dates[dates.length ~/ 2],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: textMutedColor,
                    ),
                  ),
                Text(
                  dates.last,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendSeries> seriesList;
  final double chartMin;
  final double chartMax;
  final Color gridColor;
  final bool isDark;

  _TrendChartPainter({
    required this.seriesList,
    required this.chartMin,
    required this.chartMax,
    required this.gridColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Draw subtle horizontal reference gridlines (3 lines)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 2; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final totalRange = chartMax - chartMin;
    final safeRange = totalRange > 0 ? totalRange : 1.0;

    // 2. Draw each series
    for (final series in seriesList) {
      final points = series.points;
      if (points.isEmpty) continue;

      final n = points.length;
      final stepX = n > 1 ? (size.width - 12) / (n - 1) : size.width / 2;
      final screenPoints = <Offset>[];

      for (int i = 0; i < n; i++) {
        final x = n > 1 ? 6 + (i * stepX) : size.width / 2;
        final fraction = (points[i].value - chartMin) / safeRange;
        // Invert Y so higher value is towards top
        final y = size.height - (fraction * size.height);
        screenPoints.add(Offset(x, y.clamp(0.0, size.height)));
      }

      // Draw Gradient Area Fill under line
      if (screenPoints.length > 1) {
        final fillPath = Path();
        fillPath.moveTo(screenPoints[0].dx, size.height);
        for (final pt in screenPoints) {
          fillPath.lineTo(pt.dx, pt.dy);
        }
        fillPath.lineTo(screenPoints.last.dx, size.height);
        fillPath.close();

        final fillPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              series.color.withValues(alpha: isDark ? 0.35 : 0.22),
              series.color.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill;

        canvas.drawPath(fillPath, fillPaint);

        // Draw Line Stroke Path
        final linePath = Path();
        linePath.moveTo(screenPoints[0].dx, screenPoints[0].dy);
        for (int i = 1; i < screenPoints.length; i++) {
          linePath.lineTo(screenPoints[i].dx, screenPoints[i].dy);
        }

        final strokePaint = Paint()
          ..color = series.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawPath(linePath, strokePaint);
      }

      // Draw Data Point Circles
      for (int i = 0; i < screenPoints.length; i++) {
        final pt = screenPoints[i];
        final isLast = i == screenPoints.length - 1;

        if (isLast) {
          // Highlight final (latest) point
          canvas.drawCircle(
            pt,
            5.0,
            Paint()..color = series.color,
          );
          canvas.drawCircle(
            pt,
            2.2,
            Paint()..color = Colors.white,
          );
        } else {
          canvas.drawCircle(
            pt,
            3.0,
            Paint()..color = series.color.withValues(alpha: 0.85),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.seriesList != seriesList ||
        oldDelegate.chartMin != chartMin ||
        oldDelegate.chartMax != chartMax ||
        oldDelegate.isDark != isDark;
  }
}
