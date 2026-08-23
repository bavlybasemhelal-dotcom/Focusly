import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/pomodoro_provider.dart';

/// 7-day weekly focus bar chart highlighting daily focused minutes
/// and emphasizing the most productive day of the week.
class WeeklyFocusChart extends StatelessWidget {
  final PomodoroStats stats;

  const WeeklyFocusChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    // Weekday labels (Sat to Fri in Arabic / default)
    final dayLabels = isArabic
        ? const ['سبت', 'أحد', 'إثن', 'ثلا', 'أرب', 'خمي', 'جمع']
        : const ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

    final weeklyMins = stats.weeklyMinutesPerDay;
    final maxMins = math.max(60, stats.bestDayMinutes);
    final bestDayName = dayLabels[stats.bestDayIndex];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : const Color(0xFF2E6FF2).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('weekly_focus_activity'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              if (stats.bestDayMinutes > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👑', style: TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        '$bestDayName (${stats.bestDayMinutes}m)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // 7 Vertical Bars
          SizedBox(
            height: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final mins = weeklyMins[index];
                final isBest = stats.bestDayMinutes > 0 && index == stats.bestDayIndex;
                final heightFactor = (mins / maxMins).clamp(0.06, 1.0);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Minutes tooltip above bar
                    if (mins > 0)
                      Text(
                        '${mins}m',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isBest ? const Color(0xFFF59E0B) : secondaryTextColor,
                        ),
                      )
                    else
                      const SizedBox(height: 12),

                    const SizedBox(height: 4),

                    // Bar container
                    Container(
                      width: 24,
                      height: 64 * heightFactor,
                      decoration: BoxDecoration(
                        gradient: isBest
                            ? const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : (mins > 0
                                ? AppColors.primaryGradient(context)
                                : null),
                        color: mins == 0
                            ? (isDark
                                ? Colors.white10
                                : const Color(0xFFF1F5F9))
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isBest
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Day Name
                    Text(
                      dayLabels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isBest ? FontWeight.w900 : FontWeight.w700,
                        color: isBest
                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                            : secondaryTextColor,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),

          if (stats.bestDayMinutes > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0B1238)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: brandPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${context.tr('best_day_callout_prefix')} $bestDayName ${context.tr('best_day_callout_suffix')} ${stats.bestDayMinutes} ${context.tr('minutes_short')}!',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
