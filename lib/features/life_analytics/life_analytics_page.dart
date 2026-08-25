import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../energy_mood/energy_mood_history_page.dart';
import '../energy_mood/providers/energy_mood_provider.dart';
import '../tasks/providers/tasks_provider.dart';
import 'providers/life_analytics_provider.dart';

/// Main Life Analytics page visualizing the correlation between
/// daily energy levels and task completion output, plus most productive day of week.
class LifeAnalyticsPage extends ConsumerWidget {
  const LifeAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    final checkinsAsync = ref.watch(checkinsHistoryStreamProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final summary = ref.watch(lifeAnalyticsSummaryProvider);

    final bool isLoading = checkinsAsync.isLoading || tasksAsync.isLoading;

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
              context.tr('life_analytics_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('life_analytics_subtitle'),
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : !summary.hasCheckins
              ? Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.1),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text('🧬', style: TextStyle(fontSize: 44)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          context.tr('analytics_empty_title'),
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 340),
                          child: Text(
                            context.tr('analytics_empty_subtitle'),
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                          icon: const Icon(Icons.bolt_rounded, size: 20),
                          label: Text(
                            context.tr('go_to_energy_btn'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EnergyMoodHistoryPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // =========================================================
                    // 1. "Energy Impact on Productivity" CARD
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.auto_graph_rounded,
                                    size: 18,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr('energy_impact_title'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Two Stat Boxes: High Energy vs Low Energy
                          Row(
                            children: [
                              // High Energy (>= 4) Stat Box
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('⚡', style: TextStyle(fontSize: 16)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              context.tr('avg_tasks_high_energy'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        summary.energyImpact.formattedAvgHigh,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Low Energy (<= 2) Stat Box
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.25 : 0.2),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('🪫', style: TextStyle(fontSize: 16)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              context.tr('avg_tasks_low_energy'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        summary.energyImpact.formattedAvgLow,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Insight Caption
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141F48) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Text('💡', style: TextStyle(fontSize: 15)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('energy_impact_caption'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: secondaryTextColor,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // =========================================================
                    // 2. "Most Productive Day" CARD
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withValues(alpha: isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.calendar_month_rounded,
                                    size: 18,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  context.tr('most_productive_day_title'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (!summary.mostProductiveDay.hasCompletedTasks)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Center(
                                child: Text(
                                  context.tr('no_completed_tasks'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF141F48) : const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.3 : 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.25 : 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text('🏆', style: TextStyle(fontSize: 22)),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr(summary.mostProductiveDay.dayNameKey),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          context.tr('most_productive_count', args: {
                                            'count': summary.mostProductiveDay.completedTasksCount.toString(),
                                          }),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: secondaryTextColor,
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
                    ),
                  ],
                ),
    );
  }
}
