import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'helpers/mental_health_helpers.dart';
import 'providers/mental_health_provider.dart';
import 'widgets/mental_health_form_modal.dart';
import 'widgets/mental_radar_chart.dart';

/// Main Mental Health screen displaying date selector, Daily/Weekly view toggle,
/// 5-axis Radar Chart, Personalized Tip based on lowest dimension,
/// and Today vs Yesterday comparison.
class MentalHealthPage extends ConsumerWidget {
  const MentalHealthPage({super.key});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentDate = ref.read(mentalSelectedDateProvider);

    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Color(0xFF6366F1),
                    surface: Color(0xFF0F1B4C),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Color(0xFF6366F1),
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(mentalSelectedDateProvider.notifier).setDate(picked);
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

    final allLogsAsync = ref.watch(mentalLogsStreamProvider);
    final selectedDate = ref.watch(mentalSelectedDateProvider);
    final viewMode = ref.watch(mentalViewModeProvider);
    final selectedDayLog = ref.watch(selectedDayMentalLogProvider);
    final activeLog = ref.watch(activeDisplayMentalLogProvider);
    final personalizedTip = ref.watch(personalizedTipProvider);
    final todayVsYesterday = ref.watch(todayVsYesterdayComparisonProvider);

    final dateStr = MentalHealthHelpers.formatDateKey(selectedDate);
    final weekBoundaries = MentalHealthHelpers.getWeekBoundaries(selectedDate);

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
              context.tr('mental_health_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('mental_health_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF6366F1),
            ),
            tooltip: context.tr('rate_today_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              MentalHealthFormModal.show(
                context,
                targetDate: selectedDate,
                existingLog: selectedDayLog,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.psychology_outlined, size: 20),
        label: Text(
          context.tr('rate_today_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          MentalHealthFormModal.show(
            context,
            targetDate: selectedDate,
            existingLog: selectedDayLog,
          );
        },
      ),
      body: allLogsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (allLogs) {
          // Zero entries state overall
          if (allLogs.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: isDark ? 0.15 : 0.1),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('🧘', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('mental_empty_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: Text(
                        context.tr('mental_empty_subtitle'),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: Text(
                        context.tr('rate_today_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        MentalHealthFormModal.show(
                          context,
                          targetDate: selectedDate,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Main Screen Layout
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =========================================================
              // TOP BAR: DATE SELECTOR & VIEW MODE TOGGLE (DAILY / WEEKLY)
              // =========================================================
              Row(
                children: [
                  // Date Picker Button
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      onTap: () => _pickDate(context, ref),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                              color: Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Segmented Toggle: Daily vs Weekly
                  Expanded(
                    flex: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF08123A)
                            : const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // Daily Button
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(mentalViewModeProvider.notifier)
                                    .setMode(MentalViewMode.daily);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: viewMode == MentalViewMode.daily
                                      ? (isDark
                                            ? const Color(0xFF1E2958)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow:
                                      viewMode == MentalViewMode.daily &&
                                          !isDark
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  context.tr('view_mode_daily'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: viewMode == MentalViewMode.daily
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: viewMode == MentalViewMode.daily
                                        ? (isDark
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFF4F46E5))
                                        : secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),

                          // Weekly Button
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(mentalViewModeProvider.notifier)
                                    .setMode(MentalViewMode.weekly);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: viewMode == MentalViewMode.weekly
                                      ? (isDark
                                            ? const Color(0xFF1E2958)
                                            : Colors.white)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow:
                                      viewMode == MentalViewMode.weekly &&
                                          !isDark
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  context.tr('view_mode_weekly'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        viewMode == MentalViewMode.weekly
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: viewMode == MentalViewMode.weekly
                                        ? (isDark
                                              ? const Color(0xFF00E5FF)
                                              : const Color(0xFF4F46E5))
                                        : secondaryTextColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // =========================================================
              // RADAR CHART CARD
              // =========================================================
              Container(
                padding: const EdgeInsets.all(18),
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
                    // Header with dynamic title
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
                              Icons.radar_rounded,
                              size: 18,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            viewMode == MentalViewMode.daily
                                ? context.tr(
                                    'daily_chart_title',
                                    args: {'date': dateStr},
                                  )
                                : context.tr(
                                    'weekly_chart_title',
                                    args: {
                                      'startDate':
                                          weekBoundaries.formattedStartDate,
                                      'endDate':
                                          weekBoundaries.formattedEndDate,
                                    },
                                  ),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Radar Chart or Empty Placeholder
                    if (activeLog != null)
                      MentalRadarChart(log: activeLog)
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 36,
                          horizontal: 16,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.psychology_alt_outlined,
                              size: 40,
                              color: secondaryTextColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              viewMode == MentalViewMode.daily
                                  ? context.tr('no_entry_date')
                                  : context.tr('no_entry_week'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (viewMode == MentalViewMode.daily) ...[
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: Text(
                                  context.tr('rate_this_day_btn'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  MentalHealthFormModal.show(
                                    context,
                                    targetDate: selectedDate,
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // =========================================================
              // PERSONALIZED TIP CARD (Based on lowest scoring dimension)
              // =========================================================
              if (personalizedTip != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141F48)
                        : const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                          : const Color(0xFFDDD6FE),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('personalized_tip_title'),
                                style: TextStyle(
                                  fontSize: 15,
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
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${context.tr(personalizedTip.dimensionKey)}: ${personalizedTip.score}/10',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(personalizedTip.tipKey),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE0E7FF)
                              : const Color(0xFF3730A3),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // =========================================================
              // TODAY VS YESTERDAY COMPARISON CARD (Daily mode only)
              // =========================================================
              if (viewMode == MentalViewMode.daily &&
                  selectedDayLog != null &&
                  todayVsYesterday != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.compare_arrows_rounded,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('comparison_title'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (!todayVsYesterday.hasYesterday)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                            child: Text(
                              context.tr('cmp_no_yesterday'),
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: secondaryTextColor,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: todayVsYesterday.comparisons.length,
                          separatorBuilder: (context, index) => Divider(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            height: 14,
                          ),
                          itemBuilder: (context, index) {
                            final comp = todayVsYesterday.comparisons[index];

                            String badgeText;
                            Color badgeColor;
                            Color badgeBg;

                            switch (comp.direction) {
                              case ComparisonDirection.improved:
                                badgeText = context.tr('cmp_improved');
                                badgeColor = const Color(0xFF10B981);
                                badgeBg = const Color(
                                  0xFF10B981,
                                ).withValues(alpha: isDark ? 0.2 : 0.12);
                                break;
                              case ComparisonDirection.declined:
                                badgeText = context.tr('cmp_declined');
                                badgeColor = const Color(0xFFEF4444);
                                badgeBg = const Color(
                                  0xFFEF4444,
                                ).withValues(alpha: isDark ? 0.2 : 0.12);
                                break;
                              case ComparisonDirection.same:
                                badgeText = context.tr('cmp_same');
                                badgeColor = secondaryTextColor;
                                badgeBg = secondaryTextColor.withValues(
                                  alpha: 0.12,
                                );
                                break;
                              case ComparisonDirection.noYesterday:
                                badgeText = context.tr('cmp_no_yesterday');
                                badgeColor = secondaryTextColor;
                                badgeBg = Colors.transparent;
                                break;
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr(comp.dimensionKey),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${comp.todayValue}/10',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
