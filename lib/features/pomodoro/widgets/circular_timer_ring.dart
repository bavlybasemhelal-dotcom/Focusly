import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/pomodoro_state.dart';

/// Interactive circular progress ring for the Pomodoro focus timer.
///
/// Features glowing phase gradients (electric blue for focus, emerald for breaks),
/// large centered MM:SS digits, and visual cycle session progress dots.
class CircularTimerRing extends StatelessWidget {
  final PomodoroTimerState timerState;

  const CircularTimerRing({super.key, required this.timerState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    // Phase colors
    final isWork = timerState.isWorkPhase;
    final activeGradient = isWork
        ? const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF34D399)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    final ringBaseColor = isDark
        ? const Color(0xFF0F1B4C)
        : const Color(0xFFE2E8F5);

    final glowColor = isWork
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF2563EB))
        : (isDark ? const Color(0xFF34D399) : const Color(0xFF10B981));

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow Bloom
          if (timerState.isRunning)
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 36,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

          // Custom Painted Circular Ring
          SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _TimerRingPainter(
                progress: timerState.progress,
                baseColor: ringBaseColor,
                gradient: activeGradient,
                strokeWidth: 14.0,
              ),
            ),
          ),

          // Centered Content (Phase Icon, MM:SS, Phase Title, Cycle Dots)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phase Icon Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isWork
                      ? const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.12)
                      : const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isWork ? '⚡' : (timerState.phase == PomodoroPhase.longBreak ? '🏖️' : '☕'),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.tr(timerState.phaseTitleKey),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: glowColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Large Monospaced MM:SS Digits
              Text(
                timerState.formattedTime,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -1.0,
                ),
              ),

              const SizedBox(height: 8),

              // Cycle Progress Dots (e.g. ●●○○)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  timerState.config.longBreakInterval,
                  (index) {
                    final isFilled = index < timerState.completedSessionsInCycle;
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled
                            ? glowColor
                            : (isDark ? Colors.white24 : Colors.black12),
                        boxShadow: isFilled
                            ? [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),

              if (timerState.selectedTaskTitle != null &&
                  timerState.selectedTaskTitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    timerState.selectedTaskTitle!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter that renders a smooth circular ring with gradient stroke
class _TimerRingPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color baseColor;
  final Gradient gradient;
  final double strokeWidth;

  _TimerRingPainter({
    required this.progress,
    required this.baseColor,
    required this.gradient,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 1. Draw background circle
    final basePaint = Paint()
      ..color = baseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, basePaint);

    // 2. Draw active progress arc (depleting as progress increases)
    final sweepAngle = (1.0 - progress) * 2 * math.pi;

    if (sweepAngle > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final activePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        rect,
        -math.pi / 2, // Start at top 12 o'clock
        sweepAngle,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TimerRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor;
  }
}
