import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/course_tracker_provider.dart';

/// Top stats summary card row for the Course Tracker screen.
class CourseStatsHeader extends ConsumerWidget {
  const CourseStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final activeCount = ref.watch(activeCoursesCountProvider);
    final completedCount = ref.watch(completedCoursesCountProvider);
    final totalLessons = ref.watch(totalLessonsWatchedProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // 1. Active Courses
          Expanded(
            child: _buildStatTile(
              context: context,
              label: context.tr('stat_active_courses'),
              value: activeCount.toString(),
              icon: Icons.play_circle_outline_rounded,
              accentColor: const Color(0xFF0EA5E9), // Sky Blue
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),

          // 2. Completed Courses
          Expanded(
            child: _buildStatTile(
              context: context,
              label: context.tr('stat_completed_courses'),
              value: completedCount.toString(),
              icon: Icons.check_circle_outline_rounded,
              accentColor: const Color(0xFF10B981), // Emerald
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),

          // 3. Lessons Watched
          Expanded(
            child: _buildStatTile(
              context: context,
              label: context.tr('stat_lessons_watched'),
              value: totalLessons.toString(),
              icon: Icons.video_library_outlined,
              accentColor: const Color(0xFF8B5CF6), // Royal Violet
              cardBg: cardBg,
              borderColor: borderColor,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
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
