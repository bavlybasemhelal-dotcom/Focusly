import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/pomodoro_state.dart';
import '../providers/pomodoro_provider.dart';

/// Control buttons for the Pomodoro Timer: Start/Pause, Reset, Skip,
/// and the "+1 Distraction" tracker button.
class PomodoroControls extends ConsumerWidget {
  final PomodoroTimerState timerState;

  const PomodoroControls({super.key, required this.timerState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final isRunning = timerState.isRunning;

    return Column(
      children: [
        // Distraction Counter Button (Visible during active work session)
        if (timerState.isWorkPhase && isRunning) ...[
          InkWell(
            onTap: () {
              ref.read(pomodoroTimerProvider.notifier).incrementDistraction();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F1B4C)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '+1 ${context.tr('distraction')}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  if (timerState.distractionCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${timerState.distractionCount}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        // Main Action Buttons Row (Reset - Start/Pause - Skip)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Reset Button
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black26
                        : const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.replay_rounded,
                  color: secondaryTextColor,
                  size: 24,
                ),
                tooltip: context.tr('reset'),
                onPressed: () {
                  ref.read(pomodoroTimerProvider.notifier).reset();
                },
              ),
            ),

            const SizedBox(width: 24),

            // Large Center Start / Pause Button
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: timerState.isWorkPhase
                    ? AppColors.primaryGradient(context)
                    : const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF34D399)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (timerState.isWorkPhase
                            ? brandPrimary
                            : const Color(0xFF10B981))
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    final notifier = ref.read(pomodoroTimerProvider.notifier);
                    if (isRunning) {
                      notifier.pause();
                    } else {
                      notifier.start(
                        workDoneTitle: context.tr('notification_work_done_title'),
                        breakDoneTitle: context.tr('notification_break_done_title'),
                      );
                    }
                  },
                  child: Center(
                    child: Icon(
                      isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 38,
                      color: isDark ? const Color(0xFF060B24) : Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Skip Button
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black26
                        : const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: secondaryTextColor,
                  size: 26,
                ),
                tooltip: context.tr('skip'),
                onPressed: () {
                  ref.read(pomodoroTimerProvider.notifier).skip(
                        workDoneTitle: context.tr('notification_work_done_title'),
                        breakDoneTitle: context.tr('notification_break_done_title'),
                      );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
