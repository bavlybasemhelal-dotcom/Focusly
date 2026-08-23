import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable circular progress ring with translucent track and solid arc.
class CircularProgressRing extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final int progress; // 0 to 100
  final Color? progressColor;
  final Color? trackColor;
  final bool showPercentage;
  final TextStyle? textStyle;

  const CircularProgressRing({
    super.key,
    this.size = 48.0,
    this.strokeWidth = 4.5,
    required this.progress,
    this.progressColor,
    this.trackColor,
    this.showPercentage = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgress = progress.clamp(0, 100);
    final pColor = progressColor ?? Colors.white;
    final tColor = trackColor ?? Colors.white.withValues(alpha: 0.25);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: effectiveProgress / 100.0,
              strokeWidth: strokeWidth,
              progressColor: pColor,
              trackColor: tColor,
            ),
          ),
          if (showPercentage)
            Text(
              '$effectiveProgress%',
              style: textStyle ??
                  TextStyle(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w900,
                    color: pColor,
                    letterSpacing: -0.5,
                  ),
            ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track circle
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
