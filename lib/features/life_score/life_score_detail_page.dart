import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/life_score_provider.dart';

/// Detailed breakdown page for the Weekly Life Score with past week navigation.
class LifeScoreDetailPage extends ConsumerWidget {
  const LifeScoreDetailPage({super.key});

  String _formatDateRange(DateTime start, BuildContext context) {
    final end = start.add(const Duration(days: 6));
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final startMonth = months[start.month - 1];
    final endMonth = months[end.month - 1];

    if (start.month == end.month) {
      return '$startMonth ${start.day} – ${end.day}, ${start.year}';
    } else {
      return '$startMonth ${start.day} – $endMonth ${end.day}, ${start.year}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F0);

    final selectedWeek = ref.watch(selectedWeekStartProvider);
    final currentWeek = ref.watch(currentWeekStartProvider);
    final isCurrent =
        selectedWeek.year == currentWeek.year &&
        selectedWeek.month == currentWeek.month &&
        selectedWeek.day == currentWeek.day;

    final score = ref.watch(selectedWeekLifeScoreProvider);
    final logsAsync = ref.watch(lifeScoreLogsStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('life_score_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('life_score_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: logsAsync.isLoading && !isCurrent && score == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // =============================================================
                // 1. WEEK NAVIGATOR
                // =============================================================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chevron_left_rounded,
                          color: primaryTextColor,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(selectedWeekStartProvider.notifier)
                              .previousWeek();
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDateRange(selectedWeek, context),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          if (isCurrent)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Current Week',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.chevron_right_rounded,
                          color: primaryTextColor,
                        ),
                        onPressed: isCurrent
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(selectedWeekStartProvider.notifier)
                                    .nextWeek();
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // =============================================================
                // 2. MAIN SCORE CARD OR EMPTY STATE
                // =============================================================
                if (score == null) ...[
                  // Empty state for past week with no snapshot
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        const Text('📊', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('no_data_for_week'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? 'لا توجد لقطة محفوظة لهذا الأسبوع؛ لا يمكن إعادة بناء تقييمه من الحالة الحالية.'
                              : 'No snapshot was recorded for this week. Current data cannot recreate its historical score.',
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Prominent Circular Gauge Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      children: [
                        // Circular Gauge
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: CircularProgressIndicator(
                                value: score.total / 100.0,
                                strokeWidth: 10,
                                backgroundColor: score.tierColor.withValues(
                                  alpha: isDark ? 0.2 : 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  score.tierColor,
                                ),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${score.total}',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: score.tierColor,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  '/ 100',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Qualitative Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: score.tierColor.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: score.tierColor.withValues(
                                alpha: isDark ? 0.4 : 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            context.tr(score.qualitativeKey),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: score.tierColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // =============================================================
                  // 3. BREAKDOWN TABLE
                  // =============================================================
                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  context.tr('col_section'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  context.tr('col_completion'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  context.tr('col_weight'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  context.tr('col_contribution'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: borderColor),

                        // 6 Dimension Rows
                        _buildBreakdownRow(
                          context: context,
                          icon: '📋',
                          title: context.tr('pillar_tasks'),
                          completion: score.breakdown.tasks,
                          weight: '30%',
                          contribution: score.breakdown.tasksContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                        _buildBreakdownRow(
                          context: context,
                          icon: '🔥',
                          title: context.tr('pillar_habits'),
                          completion: score.breakdown.habits,
                          weight: '25%',
                          contribution: score.breakdown.habitsContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                        _buildBreakdownRow(
                          context: context,
                          icon: '⚡',
                          title: context.tr('pillar_energy'),
                          completion: score.breakdown.energy,
                          weight: '15%',
                          contribution: score.breakdown.energyContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                        _buildBreakdownRow(
                          context: context,
                          icon: '📚',
                          title: context.tr('pillar_learning'),
                          completion: score.breakdown.learning,
                          weight: '10%',
                          contribution: score.breakdown.learningContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                        _buildBreakdownRow(
                          context: context,
                          icon: '📅',
                          title: context.tr('pillar_checkins'),
                          completion: score.breakdown.checkins,
                          weight: '10%',
                          contribution: score.breakdown.checkinsContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),
                        _buildBreakdownRow(
                          context: context,
                          icon: '🎯',
                          title: context.tr('pillar_goals'),
                          completion: score.breakdown.goals,
                          weight: '10%',
                          contribution: score.breakdown.goalsContribution,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                        ),

                        // Emphasized Total Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF141F48)
                                : const Color(0xFFF1F5F9),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text(
                                  context.tr('total_life_score'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  '${score.total} / 100',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: score.tierColor,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
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

  Widget _buildBreakdownRow({
    required BuildContext context,
    required String icon,
    required String title,
    required double completion,
    required String weight,
    required double contribution,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Section
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Completion %
          Expanded(
            flex: 2,
            child: Text(
              '${completion.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Weight %
          Expanded(
            flex: 2,
            child: Text(
              weight,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Contribution
          Expanded(
            flex: 3,
            child: Text(
              '+${contribution.toStringAsFixed(1)} pts',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF10B981),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
