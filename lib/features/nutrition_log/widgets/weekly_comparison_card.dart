import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/nutrition_log_provider.dart';

/// Card showing the week-over-week average nutrition comparison.
class WeeklyComparisonCard extends ConsumerWidget {
  const WeeklyComparisonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final accentGreen = isDark
        ? const Color(0xFF4ADE80)
        : const Color(0xFF10B981);

    final comparison = ref.watch(nutritionWeeklyComparisonProvider);

    final thisWeekStr = comparison.thisWeekAvg != null
        ? context.tr(
            'nutrition_avg_format',
            args: {'avg': comparison.thisWeekAvg!.toStringAsFixed(1)},
          )
        : '−';

    final lastWeekStr = comparison.lastWeekAvg != null
        ? context.tr(
            'nutrition_avg_format',
            args: {'avg': comparison.lastWeekAvg!.toStringAsFixed(1)},
          )
        : '−';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF6366F1,
                  ).withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                context.tr('nutrition_weekly_comparison'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 1: This Week Avg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF142255) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? accentGreen.withValues(alpha: 0.2)
                    : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 20,
                      color: accentGreen,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('nutrition_this_week_avg'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  thisWeekStr,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: accentGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Row 2: Last Week Avg
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0B1438).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 20,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('nutrition_last_week_avg'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  lastWeekStr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
