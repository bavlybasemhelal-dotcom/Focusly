import 'package:flutter/material.dart';

/// Compact 7-day sparkline line chart showing level progression over the past week.
class SparklineWidget extends StatelessWidget {
  final List<int> history;
  final Color color;
  final double width;
  final double height;

  const SparklineWidget({
    super.key,
    required this.history,
    required this.color,
    this.width = 90,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(history: history, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<int> history;
  final Color color;

  _SparklinePainter({required this.history, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final data = history.length == 7
        ? history
        : List<int>.filled(7, history.last);

    int minVal = data[0];
    int maxVal = data[0];
    for (final v in data) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    final range = (maxVal - minVal).toDouble();
    final effectiveRange = range > 0 ? range : 1.0;

    final stepX = (size.width - 8) / (data.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < data.length; i++) {
      final x = 4 + (i * stepX);
      // Invert Y so highest value is at top
      final fraction = (data[i] - minVal) / effectiveRange;
      final y = size.height - 4 - (fraction * (size.height - 8));
      points.add(Offset(x, y));
    }

    // 1. Draw gradient fill area under line
    final fillPath = Path();
    fillPath.moveTo(points[0].dx, size.height);
    for (final pt in points) {
      fillPath.lineTo(pt.dx, pt.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 2. Draw line path
    final linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // 3. Highlight the final point (Today's snapshot)
    final lastPoint = points.last;
    canvas.drawCircle(lastPoint, 4.0, Paint()..color = color);
    canvas.drawCircle(lastPoint, 1.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.history != history || oldDelegate.color != color;
  }
}
