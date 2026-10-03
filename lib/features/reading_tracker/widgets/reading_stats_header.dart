import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/reading_provider.dart';

/// Summary stat cards for Reading Tracker (Finished, Reading, Streak, Pages).
class ReadingStatsHeader extends ConsumerWidget {
  const ReadingStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(readingStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Column(
      children: [
        Row(
          children: [
            // 1. Reading Streak Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: context.tr('stat_reading_streak'),
                value: '${stats.streakDays} ${context.tr('days_unit')}',
                cardBg: cardBg,
                borderColor: stats.streakDays > 0
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                    : borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),

            // 2. Currently Reading Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.auto_stories_rounded,
                iconColor: const Color(0xFF2E6FF2),
                title: context.tr('stat_currently_reading'),
                value: '${stats.currentlyReading}',
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // 3. Books Finished Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF10B981),
                title: context.tr('stat_books_finished'),
                value: '${stats.booksFinished}',
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),

            // 4. Pages Read Card
            Expanded(
              child: _buildStatCard(
                context: context,
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF8B5CF6),
                title: context.tr('stat_pages_read'),
                value:
                    '${stats.totalPagesRead} pgs (${stats.overallProgressPercent}%)',
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
