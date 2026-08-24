import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/mental_log_model.dart';

/// Single axis dimension item for the Mental Health Radar Chart.
class MentalRadarDimension {
  final String labelKey;
  final int value; // 1 to 10
  final Color color;

  const MentalRadarDimension({
    required this.labelKey,
    required this.value,
    required this.color,
  });
}

/// Radar/Spider chart visualizing the 5 core mental wellbeing dimensions.
///
/// Axes:
/// 1. Calm (Inverted Anxiety: `11 - anxiety`)
/// 2. Happiness
/// 3. Social Energy
/// 4. Self Satisfaction
/// 5. Life Balance
class MentalRadarChart extends StatelessWidget {
  final MentalLogModel log;
  final double height;

  const MentalRadarChart({
    super.key,
    required this.log,
    this.height = 250,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dimensions = [
      MentalRadarDimension(
        labelKey: 'dimension_calm',
        value: log.calmScore,
        color: const Color(0xFF00E5FF),
      ),
      MentalRadarDimension(
        labelKey: 'dimension_happiness',
        value: log.happiness,
        color: const Color(0xFFF59E0B),
      ),
      MentalRadarDimension(
        labelKey: 'dimension_social_energy',
        value: log.socialEnergy,
        color: const Color(0xFF10B981),
      ),
      MentalRadarDimension(
        labelKey: 'dimension_self_satisfaction',
        value: log.selfSatisfaction,
        color: const Color(0xFF8B5CF6),
      ),
      MentalRadarDimension(
        labelKey: 'dimension_balance',
        value: log.balance,
        color: const Color(0xFFEC4899),
      ),
    ];

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _MentalRadarPainter(
          context: context,
          dimensions: dimensions,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _MentalRadarPainter extends CustomPainter {
  final BuildContext context;
  final List<MentalRadarDimension> dimensions;
  final bool isDark;

  _MentalRadarPainter({
    required this.context,
    required this.dimensions,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 40;
    const count = 5;
    const maxVal = 10.0;
    const ringsCount = 5;

    final gridLineColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F0);
    final gridPaint = Paint()
      ..color = gridLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw 5 concentric pentagonal rings
    for (int r = 1; r <= ringsCount; r++) {
      final ringRadius = radius * (r / ringsCount);
      final path = Path();
      for (int i = 0; i < count; i++) {
        final angle = (2 * math.pi / count) * i - (math.pi / 2);
        final x = center.dx + ringRadius * math.cos(angle);
        final y = center.dy + ringRadius * math.sin(angle);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 2. Draw radial axis lines from center to outer ring
    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 3. Draw Data Polygon
    final dataPoints = <Offset>[];
    for (int i = 0; i < count; i++) {
      final val = dimensions[i].value.clamp(1, 10);
      final fraction = (val / maxVal).clamp(0.1, 1.0);
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final r = radius * fraction;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      dataPoints.add(Offset(x, y));
    }

    final dataPath = Path()..moveTo(dataPoints[0].dx, dataPoints[0].dy);
    for (int i = 1; i < count; i++) {
      dataPath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
    }
    dataPath.close();

    // Area Fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6366F1).withValues(alpha: isDark ? 0.45 : 0.35),
          const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.25 : 0.15),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawPath(dataPath, fillPaint);

    // Stroke Border
    final strokePaint = Paint()
      ..color = const Color(0xFF6366F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(dataPath, strokePaint);

    // Vertex node circles
    for (int i = 0; i < count; i++) {
      final pt = dataPoints[i];
      final nodeColor = dimensions[i].color;
      canvas.drawCircle(pt, 5.0, Paint()..color = nodeColor);
      canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white);
    }

    // 4. Draw outer text labels with translated names and values
    final labelColor = isDark ? Colors.white70 : const Color(0xFF475569);
    for (int i = 0; i < count; i++) {
      final dim = dimensions[i];
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final labelRadius = radius + 24;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      final translatedName = context.tr(dim.labelKey);
      final labelText = '$translatedName\n(${dim.value}/10)';

      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);

      final offset = Offset(x - textPainter.width / 2, y - textPainter.height / 2);
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _MentalRadarPainter oldDelegate) {
    return oldDelegate.dimensions != dimensions || oldDelegate.isDark != isDark;
  }
}
