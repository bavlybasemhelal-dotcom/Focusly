import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/life_area_assessment_model.dart';
import 'providers/life_areas_provider.dart';
import 'widgets/assessment_form_modal.dart';
import 'widgets/wheel_of_life_radar_chart.dart';

/// Main screen for the Wheel of Life assessment feature with interactive radar visualization,
/// dual-assessment comparison overlays, and historical tracking.
class LifeAreasPage extends ConsumerWidget {
  const LifeAreasPage({super.key});

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

    final assessmentsAsync = ref.watch(lifeAreasStreamProvider);
    final assessments = assessmentsAsync.value ?? <LifeAreaAssessmentModel>[];

    final primaryAssessment = ref.watch(activePrimaryAssessmentProvider);
    final compareAssessment = ref.watch(activeCompareAssessmentProvider);

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
              context.tr('wheel_of_life_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('wheel_of_life_subtitle'),
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
      body: assessmentsAsync.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : assessments.isEmpty
          ? _buildEmptyState(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              physics: const BouncingScrollPhysics(),
              children: [
                // =========================================================
                // 1. MAIN RADAR CHART CARD (WITH COMPARISON SELECTORS)
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
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dropdown Selectors: Primary and Compare With
                      _buildDropdownSelectors(
                        context: context,
                        ref: ref,
                        assessments: assessments,
                        primaryAssessment: primaryAssessment,
                        compareAssessment: compareAssessment,
                        isDark: isDark,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                      ),
                      const SizedBox(height: 16),

                      // 8-Axis Radar Chart
                      if (primaryAssessment != null)
                        WheelOfLifeRadarChart(
                          primary: primaryAssessment,
                          comparison: compareAssessment,
                          height: 300,
                        ),

                      const SizedBox(height: 16),

                      // Legend and Comparison Summary Banner
                      _buildLegendAndSummary(
                        context: context,
                        primary: primaryAssessment,
                        comparison: compareAssessment,
                        isDark: isDark,
                        secondaryTextColor: secondaryTextColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // =========================================================
                // 2. ASSESSMENT HISTORY CARD
                // =========================================================
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('assessment_history_title'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF6366F1,
                              ).withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${assessments.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Assessment Rows
                      ...assessments.map((assessment) {
                        return _buildHistoryRow(
                          context: context,
                          ref: ref,
                          assessment: assessment,
                          isDark: isDark,
                          borderColor: borderColor,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          context.tr('add_assessment_title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          AssessmentFormModal.show(context);
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(
                  0xFF6366F1,
                ).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🎡', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('life_areas_empty_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('life_areas_empty_subtitle'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                context.tr('start_assessment_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                AssessmentFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSelectors({
    required BuildContext context,
    required WidgetRef ref,
    required List<LifeAreaAssessmentModel> assessments,
    required LifeAreaAssessmentModel? primaryAssessment,
    required LifeAreaAssessmentModel? compareAssessment,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
  }) {
    final selectedPrimaryId =
        ref.watch(selectedPrimaryAssessmentIdProvider) ??
        (assessments.isNotEmpty ? assessments.first.id : null);
    final selectedCompareId = ref.watch(selectedCompareAssessmentIdProvider);

    return Column(
      children: [
        // Primary Assessment Selector (Cyan labeled)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E5FF),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('primary_assessment_label'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00E5FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedPrimaryId,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  items: assessments.map((a) {
                    final isLatest = a.id == assessments.first.id;
                    final label = isLatest
                        ? '${a.formattedDate} ${context.tr('latest_badge')}'
                        : a.formattedDate;
                    return DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (newId) {
                    if (newId != null) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(selectedPrimaryAssessmentIdProvider.notifier)
                          .select(newId);
                      // If compare assessment was set to this newly selected primary, reset comparison
                      if (selectedCompareId == newId) {
                        ref
                            .read(selectedCompareAssessmentIdProvider.notifier)
                            .select(null);
                      }
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Compare With Selector (Orange labeled)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF97316),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('compare_with_label'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF97316),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selectedCompareId,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        context.tr('no_comparison_option'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : Colors.black45,
                        ),
                      ),
                    ),
                    ...assessments.where((a) => a.id != selectedPrimaryId).map((
                      a,
                    ) {
                      return DropdownMenuItem<String?>(
                        value: a.id,
                        child: Text(
                          a.formattedDate,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (newId) {
                    HapticFeedback.selectionClick();
                    ref
                        .read(selectedCompareAssessmentIdProvider.notifier)
                        .select(newId);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendAndSummary({
    required BuildContext context,
    required LifeAreaAssessmentModel? primary,
    required LifeAreaAssessmentModel? comparison,
    required bool isDark,
    required Color secondaryTextColor,
  }) {
    if (primary == null) return const SizedBox();

    return Column(
      children: [
        // Legend badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendBadge(
              color: const Color(0xFF00E5FF),
              text: context.tr(
                'selected_legend',
                args: {'date': primary.formattedDate},
              ),
              isDark: isDark,
            ),
            if (comparison != null) ...[
              const SizedBox(width: 12),
              _buildLegendBadge(
                color: const Color(0xFFF97316),
                text: context.tr(
                  'comparison_legend',
                  args: {'date': comparison.formattedDate},
                ),
                isDark: isDark,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Summary text line
        Text(
          comparison != null
              ? context.tr(
                  'comparing_dates_summary',
                  args: {
                    'primaryDate': primary.formattedDate,
                    'compareDate': comparison.formattedDate,
                  },
                )
              : context.tr(
                  'single_date_summary',
                  args: {'date': primary.formattedDate},
                ),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLegendBadge({
    required Color color,
    required String text,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow({
    required BuildContext context,
    required WidgetRef ref,
    required LifeAreaAssessmentModel assessment,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final careerLabel = context.tr('dimension_career');
    final financeLabel = context.tr('dimension_finance');
    final healthLabel = context.tr('dimension_health');
    final growthLabel = context.tr('dimension_growth');

    final previewText =
        '$careerLabel: ${assessment.career} • $financeLabel: ${assessment.finance} • $healthLabel: ${assessment.health} • $growthLabel: ${assessment.growth}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Emoji badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(
                0xFF6366F1,
              ).withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🎡', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 12),

          // Date and 4-metric preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assessment.formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  previewText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Edit action (pencil)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: secondaryTextColor,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.selectionClick();
              AssessmentFormModal.show(context, assessmentToEdit: assessment);
            },
          ),

          // Delete action (trash)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: const Color(0xFFEF4444),
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(context.tr('delete_assessment_dialog_title')),
                  content: Text(
                    context.tr(
                      'delete_assessment_dialog_msg',
                      args: {'date': assessment.formattedDate},
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(context.tr('cancel')),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(context.tr('delete_assessment_btn')),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                final uid = ref.read(currentUserIdProvider);
                if (uid != null && uid.isNotEmpty) {
                  await ref
                      .read(lifeAreasServiceProvider)
                      .deleteAssessment(uid, assessment.id);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
