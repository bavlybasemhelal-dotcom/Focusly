import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/checkin_model.dart';
import '../providers/energy_mood_provider.dart';

/// Lightweight, tappable water tracker widget.
///
/// Tapping glass N: if current count is N, drops to N-1; otherwise jumps to N.
/// Awards +5 XP per glass logged up to 2x daily target.
class WaterTrackerWidget extends ConsumerWidget {
  final String dateStr;
  final CheckinModel? checkin;
  final bool isCompact;

  const WaterTrackerWidget({
    super.key,
    required this.dateStr,
    this.checkin,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final target = ref.watch(dailyWaterTargetProvider);
    final currentWater = checkin?.water ?? 0;
    final isGoalMet = currentWater >= target && target > 0;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGoalMet
              ? const Color(0xFF06B6D4).withValues(alpha: 0.5)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: isGoalMet ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF06B6D4,
            ).withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, counter, and XP badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: Color(0xFF06B6D4),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('water_tracker_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isGoalMet
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$currentWater / $target ${context.tr('glasses_unit')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isGoalMet
                            ? const Color(0xFF10B981)
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Row of interactive glass icons
          LayoutBuilder(
            builder: (context, constraints) {
              final glassCount = target;
              return Wrap(
                spacing: 6,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: List.generate(glassCount, (index) {
                  final glassIndex = index + 1;
                  final isFilled = currentWater >= glassIndex;

                  return InkWell(
                    onTap: () async {
                      final uid = ref.read(currentUserIdProvider);
                      if (uid == null) return;

                      final newCount = (currentWater == glassIndex)
                          ? glassIndex - 1
                          : glassIndex;

                      final wasGoalMetBefore = currentWater >= target;
                      final isGoalMetNow = newCount >= target;

                      await ref
                          .read(energyMoodServiceProvider)
                          .updateWater(
                            uid: uid,
                            date: dateStr,
                            newWaterCount: newCount,
                            dailyTarget: target,
                            context: context,
                            ref: ref,
                          );

                      if (context.mounted &&
                          !wasGoalMetBefore &&
                          isGoalMetNow) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr('water_goal_reached_toast'),
                            ),
                            backgroundColor: const Color(0xFF06B6D4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? const Color(0xFF06B6D4).withValues(alpha: 0.2)
                            : (isDark
                                  ? const Color(0xFF08123A)
                                  : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFilled
                              ? const Color(0xFF06B6D4)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFCBD5E1)),
                          width: isFilled ? 1.5 : 1.0,
                        ),
                      ),
                      child: Icon(
                        isFilled
                            ? Icons.local_drink_rounded
                            : Icons.local_drink_outlined,
                        color: isFilled
                            ? const Color(0xFF06B6D4)
                            : secondaryTextColor,
                        size: 22,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Sleep duration and time tracker widget.
///
/// Features Bedtime & Wake-up pickers, computes overnight duration accurately,
/// and awards +15 XP once per day.
class SleepTrackerWidget extends ConsumerStatefulWidget {
  final String dateStr;
  final CheckinModel? checkin;

  const SleepTrackerWidget({super.key, required this.dateStr, this.checkin});

  @override
  ConsumerState<SleepTrackerWidget> createState() => _SleepTrackerWidgetState();
}

class _SleepTrackerWidgetState extends ConsumerState<SleepTrackerWidget> {
  TimeOfDay? _sleepTime;
  TimeOfDay? _wakeTime;

  @override
  void initState() {
    super.initState();
    _sleepTime =
        parseTimeString(widget.checkin?.sleepTime) ??
        const TimeOfDay(hour: 23, minute: 0);
    _wakeTime =
        parseTimeString(widget.checkin?.wakeTime) ??
        const TimeOfDay(hour: 7, minute: 0);
  }

  @override
  void didUpdateWidget(covariant SleepTrackerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checkin != oldWidget.checkin) {
      if (widget.checkin?.sleepTime != null) {
        _sleepTime = parseTimeString(widget.checkin!.sleepTime);
      }
      if (widget.checkin?.wakeTime != null) {
        _wakeTime = parseTimeString(widget.checkin!.wakeTime);
      }
    }
  }

  double get _computedDuration {
    if (_sleepTime == null || _wakeTime == null) return 0.0;
    return computeSleepDurationFromTime(_sleepTime!, _wakeTime!);
  }

  Future<void> _saveSleep() async {
    if (_sleepTime == null || _wakeTime == null) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    await ref
        .read(energyMoodServiceProvider)
        .updateSleep(
          uid: uid,
          date: widget.dateStr,
          sleepTime: _sleepTime!,
          wakeTime: _wakeTime!,
          context: context,
          ref: ref,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final duration = _computedDuration;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF6366F1,
            ).withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Sleep Title + Computed Hours Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bedtime_rounded,
                      color: Color(0xFF6366F1),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('sleep_tracker_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${duration.toStringAsFixed(1)} ${context.tr('hours_unit')}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Two Time Pickers: Sleep Time and Wake Time
          Row(
            children: [
              // Bedtime Box
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          _sleepTime ?? const TimeOfDay(hour: 23, minute: 0),
                    );
                    if (picked != null) {
                      setState(() {
                        _sleepTime = picked;
                      });
                      await _saveSleep();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF08123A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.nightlight_round,
                              size: 14,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('bedtime_label'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _sleepTime != null
                              ? formatTimeOfDay(_sleepTime!)
                              : '--:--',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Wake-up Box
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          _wakeTime ?? const TimeOfDay(hour: 7, minute: 0),
                    );
                    if (picked != null) {
                      setState(() {
                        _wakeTime = picked;
                      });
                      await _saveSleep();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF08123A)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wb_sunny_rounded,
                              size: 14,
                              color: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('wake_time_label'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _wakeTime != null
                              ? formatTimeOfDay(_wakeTime!)
                              : '--:--',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
