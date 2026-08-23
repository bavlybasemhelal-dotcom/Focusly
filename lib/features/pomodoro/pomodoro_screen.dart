import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/models/task_model.dart';
import '../tasks/providers/tasks_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'widgets/circular_timer_ring.dart';
import 'widgets/pomodoro_controls.dart';
import 'widgets/pomodoro_settings_sheet.dart';
import 'widgets/weekly_focus_chart.dart';
import '../focus_mode/focus_mode_page.dart';

/// Main Pomodoro Timer screen in Focusly.
///
/// Features a large circular countdown ring, associated-task selector,
/// distraction tracking, today's summary metrics, and weekly focus activity chart.
class PomodoroScreen extends ConsumerWidget {
  const PomodoroScreen({super.key});

  void _openSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PomodoroSettingsSheet(),
    );
  }

  void _showTaskPicker(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final sheetBg = isDark ? const Color(0xFF0A1238) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF1F5F9);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    final tasksAsync = ref.read(tasksStreamProvider);
    final tasks = tasksAsync.value?.where((t) => !t.done).toList() ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle Pill
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text(
              context.tr('select_task_for_session'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 12),

            // Option 1: Generic Focus Session
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor),
              ),
              tileColor: cardBg,
              leading: const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB)),
              title: Text(
                context.tr('generic_focus_session'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryTextColor,
                ),
              ),
              onTap: () {
                ref.read(pomodoroTimerProvider.notifier).setSelectedTask(
                      null,
                      null,
                    );
                Navigator.of(bottomSheetContext).pop();
              },
            ),
            const SizedBox(height: 8),

            // Tasks List
            if (tasks.isNotEmpty) ...[
              Expanded(
                child: ListView.separated(
                  itemCount: tasks.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final TaskModel task = tasks[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: borderColor),
                      ),
                      tileColor: cardBg,
                      leading: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF38BDF8),
                        size: 20,
                      ),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: primaryTextColor,
                        ),
                      ),
                      subtitle: task.notes != null && task.notes!.isNotEmpty
                          ? Text(
                              task.notes!,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () {
                        ref.read(pomodoroTimerProvider.notifier).setSelectedTask(
                              task.id,
                              task.title,
                            );
                        Navigator.of(bottomSheetContext).pop();
                      },
                    );
                  },
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    context.tr('no_active_tasks'),
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final timerState = ref.watch(pomodoroTimerProvider);
    final stats = ref.watch(pomodoroStatsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Aurora Background Glows
          _buildAmbientGlowBlooms(isDark, timerState.isWorkPhase),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // -----------------------------------------------------------
                  // 1. SCREEN HEADER ROW
                  // -----------------------------------------------------------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('pomodoro'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('pomodoro_subtitle'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      // Header Action Buttons (Focus Mode + Settings)
                      Row(
                        children: [
                          // Enter Focus Mode Button
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F5),
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.center_focus_strong_rounded,
                                color: brandPrimary,
                                size: 20,
                              ),
                              tooltip: context.tr('enter_focus_mode_btn'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const FocusModePage()),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Settings Gear Action
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFFE2E8F5),
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.tune_rounded,
                                color: brandPrimary,
                                size: 20,
                              ),
                              tooltip: context.tr('pomodoro_settings'),
                              onPressed: () => _openSettingsSheet(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // -----------------------------------------------------------
                  // 2. TASK PICKER (Pre-start work phase only)
                  // -----------------------------------------------------------
                  if (timerState.isWorkPhase && !timerState.isRunning) ...[
                    InkWell(
                      onTap: () => _showTaskPicker(context, ref),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F1B4C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE2E8F5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E6FF2).withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.link_rounded,
                              size: 16,
                              color: timerState.selectedTaskTitle != null
                                  ? brandPrimary
                                  : secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                timerState.selectedTaskTitle ??
                                    context.tr('link_task_optional'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: timerState.selectedTaskTitle != null
                                      ? primaryTextColor
                                      : secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // -----------------------------------------------------------
                  // 3. CIRCULAR COUNTDOWN TIMER RING
                  // -----------------------------------------------------------
                  CircularTimerRing(timerState: timerState),

                  const SizedBox(height: 28),

                  // -----------------------------------------------------------
                  // 4. TIMER CONTROLS (Start/Pause, Reset, Skip, Distraction)
                  // -----------------------------------------------------------
                  PomodoroControls(timerState: timerState),

                  const SizedBox(height: 28),

                  // -----------------------------------------------------------
                  // 5. TODAY'S STATS SUMMARY STRIP
                  // -----------------------------------------------------------
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F1B4C)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFFE2E8F5),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Today Sessions
                        Row(
                          children: [
                            const Text('🍅', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              '${stats.todaySessionsCount} ${context.tr('focus_sessions_today')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),

                        Container(
                          width: 1,
                          height: 18,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),

                        // Today Minutes
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time_filled_rounded,
                              size: 16,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${stats.todayFocusedMinutes} ${context.tr('minutes_focused_today')}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // 6. WEEKLY FOCUS BAR CHART
                  // -----------------------------------------------------------
                  WeeklyFocusChart(stats: stats),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark, bool isWork) {
    final primaryGlow = isWork
        ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF38BDF8))
        : (isDark ? const Color(0xFF10B981) : const Color(0xFF34D399));

    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryGlow.withValues(alpha: isDark ? 0.12 : 0.15),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isWork ? const Color(0xFF38BDF8) : const Color(0xFF10B981))
                  .withValues(alpha: isDark ? 0.08 : 0.1),
            ),
          ),
        ),
      ],
    );
  }
}
