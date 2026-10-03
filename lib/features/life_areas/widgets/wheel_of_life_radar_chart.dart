import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/life_area_assessment_model.dart';

/// Single dimension axis descriptor for the 8-axis Wheel of Life
class WheelOfLifeDimension {
  final String labelKey;
  final int primaryValue; // 1 to 10
  final int? compareValue; // 1 to 10 (optional)

  const WheelOfLifeDimension({
    required this.labelKey,
    required this.primaryValue,
    this.compareValue,
  });
}

/// 8-axis, 10-ring interactive Radar Chart for Wheel of Life assessments,
/// supporting dual-assessment comparison overlays.
class WheelOfLifeRadarChart extends StatelessWidget {
  final LifeAreaAssessmentModel primary;
  final LifeAreaAssessmentModel? comparison;
  final double height;

  const WheelOfLifeRadarChart({
    super.key,
    required this.primary,
    this.comparison,
    this.height = 320,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final dimensions = [
      WheelOfLifeDimension(
        labelKey: 'dimension_career',
        primaryValue: primary.career,
        compareValue: comparison?.career,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_finance',
        primaryValue: primary.finance,
        compareValue: comparison?.finance,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_health',
        primaryValue: primary.health,
        compareValue: comparison?.health,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_family',
        primaryValue: primary.family,
        compareValue: comparison?.family,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_romance',
        primaryValue: primary.romance,
        compareValue: comparison?.romance,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_growth',
        primaryValue: primary.growth,
        compareValue: comparison?.growth,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_fun',
        primaryValue: primary.fun,
        compareValue: comparison?.fun,
      ),
      WheelOfLifeDimension(
        labelKey: 'dimension_environment',
        primaryValue: primary.environment,
        compareValue: comparison?.environment,
      ),
    ];

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WheelOfLifePainter(
          context: context,
          dimensions: dimensions,
          hasComparison: comparison != null,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _WheelOfLifePainter extends CustomPainter {
  final BuildContext context;
  final List<WheelOfLifeDimension> dimensions;
  final bool hasComparison;
  final bool isDark;

  static const int ringCount = 10;
  static const Color primaryColor = Color(0xFF00E5FF); // Vibrant Cyan
  static const Color compareColor = Color(0xFFF97316); // Vibrant Orange

  _WheelOfLifePainter({
    required this.context,
    required this.dimensions,
    required this.hasComparison,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 44;
    final int count = dimensions.length;
    final double angleStep = (2 * math.pi) / count;

    // Grid paints
    final gridLinePaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisLinePaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.18)
          : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // 1. Draw 10 Concentric Grid Rings (Octagons)
    for (int r = 1; r <= ringCount; r++) {
      final ringRadius = radius * (r / ringCount);
      final ringPath = Path();

      for (int i = 0; i < count; i++) {
        final angle = -math.pi / 2 + i * angleStep;
        final x = center.dx + ringRadius * math.cos(angle);
        final y = center.dy + ringRadius * math.sin(angle);

        if (i == 0) {
          ringPath.moveTo(x, y);
        } else {
          ringPath.lineTo(x, y);
        }
      }
      ringPath.close();

      // Alternate subtle fill on even rings
      if (r % 2 == 0) {
        final fillPaint = Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.black.withValues(alpha: 0.015)
          ..style = PaintingStyle.fill;
        canvas.drawPath(ringPath, fillPaint);
      }

      canvas.drawPath(ringPath, gridLinePaint);
    }

    // 2. Draw 8 Radial Spokes
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), axisLinePaint);
    }

    // 3. Draw Comparison Polygon (if present - rendered behind primary)
    if (hasComparison) {
      final compareFillPath = Path();
      final comparePoints = <Offset>[];

      for (int i = 0; i < count; i++) {
        final val = (dimensions[i].compareValue ?? 5).clamp(1, 10);
        final scoreRadius = radius * (val / 10.0);
        final angle = -math.pi / 2 + i * angleStep;
        final point = Offset(
          center.dx + scoreRadius * math.cos(angle),
          center.dy + scoreRadius * math.sin(angle),
        );
        comparePoints.add(point);

        if (i == 0) {
          compareFillPath.moveTo(point.dx, point.dy);
        } else {
          compareFillPath.lineTo(point.dx, point.dy);
        }
      }
      compareFillPath.close();

      // Comparison fill
      final compareFillPaint = Paint()
        ..color = compareColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawPath(compareFillPath, compareFillPaint);

      // Comparison stroke
      final compareStrokePaint = Paint()
        ..color = compareColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(compareFillPath, compareStrokePaint);

      // Comparison vertex nodes
      final nodePaint = Paint()..color = compareColor;
      for (final p in comparePoints) {
        canvas.drawCircle(p, 3.5, nodePaint);
      }
    }

    // 4. Draw Primary Polygon (Front layer)
    final primaryFillPath = Path();
    final primaryPoints = <Offset>[];

    for (int i = 0; i < count; i++) {
      final val = dimensions[i].primaryValue.clamp(1, 10);
      final scoreRadius = radius * (val / 10.0);
      final angle = -math.pi / 2 + i * angleStep;
      final point = Offset(
        center.dx + scoreRadius * math.cos(angle),
        center.dy + scoreRadius * math.sin(angle),
      );
      primaryPoints.add(point);

      if (i == 0) {
        primaryFillPath.moveTo(point.dx, point.dy);
      } else {
        primaryFillPath.lineTo(point.dx, point.dy);
      }
    }
    primaryFillPath.close();

    // Primary fill with smooth gradient / translucent color
    final primaryFillPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawPath(primaryFillPath, primaryFillPaint);

    // Primary stroke
    final primaryStrokePaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(primaryFillPath, primaryStrokePaint);

    // Primary vertex nodes with white center
    final primaryNodePaint = Paint()..color = primaryColor;
    final primaryCenterPaint = Paint()
      ..color = isDark ? const Color(0xFF0F172A) : Colors.white;

    for (final p in primaryPoints) {
      canvas.drawCircle(p, 4.5, primaryNodePaint);
      canvas.drawCircle(p, 2.0, primaryCenterPaint);
    }

    // 5. Draw Axis Labels around Perimeter
    for (int i = 0; i < count; i++) {
      final angle = -math.pi / 2 + i * angleStep;
      final labelRadius = radius + 22;
      final lx = center.dx + labelRadius * math.cos(angle);
      final ly = center.dy + labelRadius * math.sin(angle);

      final labelText = context.tr(dimensions[i].labelKey);
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: isDark
              ? Colors.white.withValues(alpha: 0.85)
              : const Color(0xFF334155),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      );

      final tp = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: 70);

      // Center the text painter on the projected label point
      final textOffset = Offset(lx - tp.width / 2, ly - tp.height / 2);

      tp.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _WheelOfLifePainter oldDelegate) {
    return oldDelegate.dimensions != dimensions ||
        oldDelegate.hasComparison != hasComparison ||
        oldDelegate.isDark != isDark;
  }
}
