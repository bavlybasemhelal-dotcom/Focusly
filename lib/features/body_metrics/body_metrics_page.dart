import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'helpers/body_metrics_helpers.dart';
import 'models/body_metric_model.dart';
import 'providers/body_metrics_provider.dart';
import 'widgets/body_metric_form_modal.dart';
import 'widgets/body_metric_stat_card.dart';
import 'widgets/trend_line_chart.dart';

/// Main Body Metrics screen with latest readings stats, trend line charts,
/// history list with inline measurement chips, and modal integration.
class BodyMetricsPage extends ConsumerWidget {
  const BodyMetricsPage({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BodyMetricModel metric,
  ) async {
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          dialogCtx.tr('metric_delete_confirm_title'),
          style: TextStyle(
            color: AppColors.textPrimary(dialogCtx),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          dialogCtx.tr('metric_delete_confirm_msg'),
          style: TextStyle(
            color: AppColors.textSecondary(dialogCtx),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete_workout_confirm_title')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      final success = await ref
          .read(bodyMetricsServiceProvider)
          .deleteMetric(uid: uid, metricId: metric.id);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('metric_deleted_toast')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildChartContainer({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Icon(icon, size: 16, color: iconColor)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildNotEnoughReadingsPlaceholder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = AppColors.textSecondary(context);

    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF1F5F9),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: 20,
            color: secondaryTextColor.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 8),
          Text(
            context.tr('not_enough_readings'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: secondaryTextColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
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

    final allMetricsAsync = ref.watch(bodyMetricsStreamProvider);
    final latestReadings = ref.watch(latestBodyReadingsProvider);
    final weightPoints = ref.watch(weightSeriesProvider);
    final pulsePoints = ref.watch(pulseSeriesProvider);
    final bpSeries = ref.watch(bpSeriesProvider);

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
              context.tr('body_metrics_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('body_metrics_subtitle'),
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
              color: Color(0xFF10B981),
            ),
            tooltip: context.tr('add_metric_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              BodyMetricFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.monitor_weight_outlined, size: 20),
        label: Text(
          context.tr('add_metric_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          BodyMetricFormModal.show(context);
        },
      ),
      body: allMetricsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
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
        data: (allMetrics) {
          // Zero entries state
          if (allMetrics.isEmpty) {
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
                          0xFF10B981,
                        ).withValues(alpha: isDark ? 0.15 : 0.1),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text('⚖️', style: TextStyle(fontSize: 44)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      context.tr('body_metrics_empty_title'),
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
                        context.tr('body_metrics_empty_subtitle'),
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
                        backgroundColor: const Color(0xFF10B981),
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
                        context.tr('add_metric_btn'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        BodyMetricFormModal.show(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          // Format latest readings strings
          final weightDisplay = latestReadings.hasWeight
              ? context.tr(
                  'weight_val_format',
                  args: {
                    'val': latestReadings.latestWeight! % 1 == 0
                        ? latestReadings.latestWeight!.toInt().toString()
                        : latestReadings.latestWeight!.toStringAsFixed(1),
                  },
                )
              : '−';

          final bpDisplay = latestReadings.hasBp
              ? context.tr(
                  'bp_val_format',
                  args: {
                    'sys': latestReadings.latestSystolic.toString(),
                    'dia': latestReadings.latestDiastolic.toString(),
                  },
                )
              : '−';

          final pulseDisplay = latestReadings.hasPulse
              ? context.tr(
                  'pulse_val_format',
                  args: {'val': latestReadings.latestPulse.toString()},
                )
              : '−';

          final weightDateStr = latestReadings.weightDate != null
              ? BodyMetricsHelpers.formatMonthDay(latestReadings.weightDate!)
              : null;
          final bpDateStr = latestReadings.bpDate != null
              ? BodyMetricsHelpers.formatMonthDay(latestReadings.bpDate!)
              : null;
          final pulseDateStr = latestReadings.pulseDate != null
              ? BodyMetricsHelpers.formatMonthDay(latestReadings.pulseDate!)
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =========================================================
              // SECTION 1: LATEST READINGS STAT ROW (3 Cards)
              // =========================================================
              Row(
                children: [
                  // Latest Weight
                  Expanded(
                    child: BodyMetricStatCard(
                      icon: Icons.scale_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: context.tr('latest_weight_label'),
                      value: weightDisplay,
                      valueColor: const Color(0xFF10B981),
                      dateSubtitle: weightDateStr,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Blood Pressure
                  Expanded(
                    child: BodyMetricStatCard(
                      icon: Icons.favorite_rounded,
                      iconColor: const Color(0xFFEF4444),
                      label: context.tr('latest_bp_label'),
                      value: bpDisplay,
                      valueColor: const Color(0xFFEF4444),
                      dateSubtitle: bpDateStr,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pulse
                  Expanded(
                    child: BodyMetricStatCard(
                      icon: Icons.bolt_rounded,
                      iconColor: isDark
                          ? AppColors.cyanElectric
                          : const Color(0xFF0EA5E9),
                      label: context.tr('latest_pulse_label'),
                      value: pulseDisplay,
                      valueColor: isDark
                          ? AppColors.cyanElectric
                          : const Color(0xFF0EA5E9),
                      dateSubtitle: pulseDateStr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // =========================================================
              // SECTION 2: THREE TREND LINE CHARTS
              // =========================================================

              // Chart 1: Weight Over Time (Single Line, accent-green)
              _buildChartContainer(
                context: context,
                title: context.tr('weight_trend_title'),
                icon: Icons.show_chart_rounded,
                iconColor: const Color(0xFF10B981),
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                child: weightPoints.length >= 2
                    ? TrendLineChart(
                        seriesList: [
                          TrendSeries(
                            points: weightPoints,
                            color: const Color(0xFF10B981),
                            label: context.tr('latest_weight_label'),
                          ),
                        ],
                      )
                    : _buildNotEnoughReadingsPlaceholder(context),
              ),
              const SizedBox(height: 16),

              // Chart 2: Blood Pressure Over Time (Dual Line: Systolic in red, Diastolic in pink)
              _buildChartContainer(
                context: context,
                title: context.tr('bp_trend_title'),
                icon: Icons.favorite_rounded,
                iconColor: const Color(0xFFEF4444),
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                child: bpSeries.hasEnoughPoints
                    ? TrendLineChart(
                        showLegend: true,
                        seriesList: [
                          TrendSeries(
                            points: bpSeries.systolicPoints,
                            color: const Color(0xFFEF4444),
                            label: context.tr('systolic_label'),
                          ),
                          TrendSeries(
                            points: bpSeries.diastolicPoints,
                            color: const Color(0xFFF43F5E),
                            label: context.tr('diastolic_label'),
                          ),
                        ],
                      )
                    : _buildNotEnoughReadingsPlaceholder(context),
              ),
              const SizedBox(height: 16),

              // Chart 3: Pulse Over Time (Single Line, cyan)
              _buildChartContainer(
                context: context,
                title: context.tr('pulse_trend_title'),
                icon: Icons.bolt_rounded,
                iconColor: isDark
                    ? AppColors.cyanElectric
                    : const Color(0xFF0EA5E9),
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                child: pulsePoints.length >= 2
                    ? TrendLineChart(
                        seriesList: [
                          TrendSeries(
                            points: pulsePoints,
                            color: isDark
                                ? AppColors.cyanElectric
                                : const Color(0xFF0EA5E9),
                            label: context.tr('latest_pulse_label'),
                          ),
                        ],
                      )
                    : _buildNotEnoughReadingsPlaceholder(context),
              ),
              const SizedBox(height: 20),

              // =========================================================
              // SECTION 3: HISTORY LIST (Reverse-chronological)
              // =========================================================
              Container(
                padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header: Title & "Add" button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('body_metrics_history'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            visualDensity: VisualDensity.compact,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            context.tr('add_metric_btn'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            BodyMetricFormModal.show(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // History Items
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: allMetrics.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1F5F9),
                        height: 16,
                        thickness: 1,
                      ),
                      itemBuilder: (context, index) {
                        final item = allMetrics[index];
                        final dateStr = BodyMetricsHelpers.formatDateKey(
                          item.date,
                        );

                        // Build inline measurement chips
                        final List<Widget> chips = [];
                        if (item.hasWeight) {
                          chips.add(
                            Text(
                              '⚖️ ${item.weight! % 1 == 0 ? item.weight!.toInt() : item.weight} ${context.tr('kg_unit')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          );
                        }
                        if (item.hasCompleteBp) {
                          chips.add(
                            Text(
                              '❤️ ${item.bpSystolic}/${item.bpDiastolic}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          );
                        }
                        if (item.hasPulse) {
                          chips.add(
                            Text(
                              '💓 ${item.pulse} ${context.tr('bpm_unit')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.cyanElectric
                                    : const Color(0xFF0EA5E9),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Date + Chips + Edit/Delete Actions
                              Row(
                                children: [
                                  // Date in bold accent-green
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Inline measurement chips separated by "•"
                                  Expanded(
                                    child: chips.isEmpty
                                        ? const SizedBox.shrink()
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: List.generate(
                                              chips.length * 2 - 1,
                                              (chipIdx) {
                                                if (chipIdx.isOdd) {
                                                  return Text(
                                                    '•',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: secondaryTextColor
                                                          .withValues(
                                                            alpha: 0.5,
                                                          ),
                                                    ),
                                                  );
                                                }
                                                return chips[chipIdx ~/ 2];
                                              },
                                            ),
                                          ),
                                  ),

                                  // Edit & Delete Actions
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                          color: secondaryTextColor,
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Edit',
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          BodyMetricFormModal.show(
                                            context,
                                            metricToEdit: item,
                                            initialDate: item.date,
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Color(0xFFEF4444),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Delete',
                                        onPressed: () =>
                                            _confirmDelete(context, ref, item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // Optional Note Panel (Inset/Quoted)
                              if (item.note != null &&
                                  item.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF0B1438,
                                          ).withValues(alpha: 0.6)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border(
                                      left: BorderSide(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.7),
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    item.note!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
