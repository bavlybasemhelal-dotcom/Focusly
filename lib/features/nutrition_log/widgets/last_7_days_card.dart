import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/nutrition_log_helpers.dart';
import '../providers/nutrition_log_provider.dart';
import 'nutrition_form_modal.dart';

/// Card displaying the 7-day visual emoji scale and quick "Rate Today" action.
class Last7DaysCard extends ConsumerWidget {
  const Last7DaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandAccent = isDark ? AppColors.cyanElectric : AppColors.primaryBlueVibrant;

    final timelineCells = ref.watch(nutrition7DayTimelineProvider);

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
          // Header: Title & "Rate Today" text button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: brandAccent.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.calendar_today_rounded,
                        size: 16,
                        color: brandAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('nutrition_last_7_days'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: isDark ? const Color(0xFF4ADE80) : const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: Text(
                  context.tr('nutrition_rate_today'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  // Check if today already has a log
                  final todayCell = timelineCells.isNotEmpty ? timelineCells.last : null;
                  NutritionFormModal.show(
                    context,
                    logToEdit: todayCell?.log,
                    initialDate: DateTime.now(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day row of emoji cells
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: timelineCells.map((cell) {
                  final isToday = cell.dayOffset == 0;
                  final hasLog = cell.rating != null;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          NutritionFormModal.show(
                            context,
                            logToEdit: cell.log,
                            initialDate: cell.date,
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? (isDark
                                    ? const Color(0xFF1E2958)
                                    : const Color(0xFFEEF2FF))
                                : (isDark
                                    ? const Color(0xFF0B1438).withValues(alpha: 0.6)
                                    : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isToday
                                  ? (isDark
                                      ? AppColors.cyanElectric.withValues(alpha: 0.5)
                                      : const Color(0xFF6366F1).withValues(alpha: 0.5))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFE2E8F0)),
                              width: isToday ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Emoji
                              Text(
                                cell.emoji,
                                style: TextStyle(
                                  fontSize: 22,
                                  color: hasLog ? null : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 6),

                              // Date in MM-DD
                              Text(
                                cell.formattedMonthDay,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                  color: isToday
                                      ? (isDark ? AppColors.cyanElectric : const Color(0xFF4F46E5))
                                      : secondaryTextColor.withValues(alpha: 0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
