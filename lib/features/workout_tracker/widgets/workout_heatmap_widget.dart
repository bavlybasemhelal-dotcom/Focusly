import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/workout_provider.dart';

/// Widget displaying a 30-day streak heatmap grid.
class WorkoutHeatmapWidget extends ConsumerWidget {
  const WorkoutHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final emptyCellBg = isDark
        ? const Color(0xFF08123A)
        : const Color(0xFFF1F5F9);

    final heatmapDays = ref.watch(workoutHeatmapProvider);
    final activeDaysCount = heatmapDays.where((d) => d.hasWorkout).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('streak_heatmap_header'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$activeDaysCount / 30 days',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('streak_heatmap_subtitle'),
            style: TextStyle(fontSize: 11, color: secondaryTextColor),
          ),
          const SizedBox(height: 14),

          // 30 Cells Grid (6 Columns × 5 Rows)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: heatmapDays.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              final day = heatmapDays[index];
              final hasWorkout = day.hasWorkout;
              final isToday = index == heatmapDays.length - 1;

              final dateStr = '${day.date.month}/${day.date.day}';

              return Tooltip(
                message: hasWorkout
                    ? '$dateStr: ${day.totalDurationMin} min (${day.totalCalories} kcal)'
                    : '$dateStr: Rest day',
                child: Container(
                  decoration: BoxDecoration(
                    color: hasWorkout ? const Color(0xFF10B981) : emptyCellBg,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F1B4C),
                            width: 1.5,
                          )
                        : Border.all(
                            color: hasWorkout
                                ? const Color(0xFF059669)
                                : borderColor,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      '${day.date.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: hasWorkout
                            ? Colors.white
                            : secondaryTextColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
