import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/skill_model.dart';

/// Radar/Spider chart visualizing proficiency levels across all skills.
class RadarChartWidget extends StatelessWidget {
  final List<SkillModel> skills;

  const RadarChartWidget({
    super.key,
    required this.skills,
  });

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            width: double.infinity,
            child: CustomPaint(
              painter: _RadarChartPainter(
                skills: skills,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarChartPainter extends CustomPainter {
  final List<SkillModel> skills;
  final bool isDark;

  _RadarChartPainter({
    required this.skills,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 34;
    final count = skills.length;

    // Find max level for dynamic scaling (minimum of 5)
    int maxLevel = 5;
    for (final s in skills) {
      if (s.level > maxLevel) {
        maxLevel = s.level;
      }
    }

    final gridLineColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0);
    final gridPaint = Paint()
      ..color = gridLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const ringsCount = 5;

    // 1. Draw concentric rings
    for (int r = 1; r <= ringsCount; r++) {
      final ringRadius = radius * (r / ringsCount);
      if (count >= 3) {
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
      } else {
        canvas.drawCircle(center, ringRadius, gridPaint);
      }
    }

    // 2. Draw radial axes from center
    for (int i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 3. Draw Skill Data Polygon
    final dataPoints = <Offset>[];
    for (int i = 0; i < count; i++) {
      final skill = skills[i];
      final normalizedFraction = (skill.level / maxLevel).clamp(0.1, 1.0);
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final r = radius * normalizedFraction;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      dataPoints.add(Offset(x, y));
    }

    if (dataPoints.isNotEmpty) {
      final dataPath = Path();
      if (count >= 3) {
        dataPath.moveTo(dataPoints[0].dx, dataPoints[0].dy);
        for (int i = 1; i < count; i++) {
          dataPath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
        }
        dataPath.close();
      } else if (count == 2) {
        dataPath.moveTo(dataPoints[0].dx, dataPoints[0].dy);
        dataPath.lineTo(dataPoints[1].dx, dataPoints[1].dy);
      } else {
        // 1 skill
        canvas.drawCircle(
          dataPoints[0],
          8,
          Paint()..color = const Color(0xFF2E6FF2),
        );
      }

      if (count >= 3) {
        // Filled semi-transparent area
        final fillPaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF2E6FF2).withValues(alpha: 0.45),
              const Color(0xFF00D2FF).withValues(alpha: 0.25),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromCircle(center: center, radius: radius))
          ..style = PaintingStyle.fill;
        canvas.drawPath(dataPath, fillPaint);

        // Glowing border line
        final strokePaint = Paint()
          ..color = const Color(0xFF2E6FF2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(dataPath, strokePaint);
      } else if (count == 2) {
        final strokePaint = Paint()
          ..color = const Color(0xFF2E6FF2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawPath(dataPath, strokePaint);
      }

      // Draw vertex nodes
      for (int i = 0; i < dataPoints.length; i++) {
        final pt = dataPoints[i];
        final nodeColor = Color(skills[i].color);
        // Outer dot
        canvas.drawCircle(pt, 5.0, Paint()..color = nodeColor);
        // Inner white highlight
        canvas.drawCircle(pt, 2.0, Paint()..color = Colors.white);
      }
    }

    // 4. Draw outer label text
    final labelColor = isDark ? Colors.white70 : const Color(0xFF475569);
    for (int i = 0; i < count; i++) {
      final skill = skills[i];
      final angle = (2 * math.pi / count) * i - (math.pi / 2);
      final labelRadius = radius + 22;
      final x = center.dx + labelRadius * math.cos(angle);
      final y = center.dy + labelRadius * math.sin(angle);

      final labelText = '${skill.name}\n(Lvl ${skill.level})';
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 80);

      final offset = Offset(x - textPainter.width / 2, y - textPainter.height / 2);
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarChartPainter oldDelegate) {
    return oldDelegate.skills != skills || oldDelegate.isDark != isDark;
  }
}
