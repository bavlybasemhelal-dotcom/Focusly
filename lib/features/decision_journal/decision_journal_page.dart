import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/decision_model.dart';
import 'providers/decision_journal_provider.dart';
import 'widgets/decision_card.dart';
import 'widgets/decision_form_modal.dart';
import 'widgets/decision_stats_header.dart';

/// Decision Journal screen for logging important decisions (rationale + prediction)
/// and coming back later to evaluate actual outcomes.
class DecisionJournalPage extends ConsumerWidget {
  const DecisionJournalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final decisionsAsync = ref.watch(decisionsStreamProvider);
    final currentFilter = ref.watch(decisionFilterProvider);
    final filteredList = ref.watch(filteredDecisionsProvider);

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
              context.tr('decision_journal_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('decision_journal_subtitle'),
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
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2E6FF2)),
            tooltip: context.tr('log_decision_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              DecisionFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E6FF2),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          context.tr('log_decision_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          DecisionFormModal.show(context);
        },
      ),
      body: decisionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF2E6FF2)),
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
        data: (allDecisions) {
          if (allDecisions.isEmpty) {
            return _buildEmptyState(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Dual Summary Stat Cards (Pending vs. Reviewed)
              const DecisionStatsHeader(),
              const SizedBox(height: 18),

              // 2. Filter Selector Chips (All / Pending / Reviewed)
              _buildFilterChips(
                context,
                ref,
                currentFilter,
                allDecisions,
                isDark,
                primaryTextColor,
                secondaryTextColor,
              ),
              const SizedBox(height: 16),

              // 3. List of Decisions or Filter Empty State
              if (filteredList.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: Text(
                      context.tr('empty_decisions_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                ...filteredList.map((decision) => DecisionCard(decision: decision)),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Builds the filter pills (All, Pending Review, Reviewed).
  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    DecisionFilter activeFilter,
    List<DecisionModel> allDecisions,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final pendingCount = allDecisions.where((d) => !d.reviewed).length;
    final reviewedCount = allDecisions.where((d) => d.reviewed).length;

    final filters = [
      {
        'filter': DecisionFilter.all,
        'label': context.tr('filter_all_decisions'),
        'count': allDecisions.length,
      },
      {
        'filter': DecisionFilter.pending,
        'label': context.tr('filter_pending_decisions'),
        'count': pendingCount,
      },
      {
        'filter': DecisionFilter.reviewed,
        'label': context.tr('filter_reviewed_decisions'),
        'count': reviewedCount,
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final filterType = item['filter'] as DecisionFilter;
          final isSelected = activeFilter == filterType;
          final label = item['label'] as String;
          final count = item['count'] as int;

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(decisionFilterProvider.notifier).setFilter(filterType);
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E6FF2)
                      : (isDark ? const Color(0xFF0F1B4C) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2E6FF2)
                        : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Empty state view when no decisions have been logged yet.
  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E3A8A).withValues(alpha: 0.5),
                          const Color(0xFF0F1B4C),
                        ]
                      : [
                          const Color(0xFFDBEAFE),
                          const Color(0xFFEFF6FF),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E6FF2).withValues(alpha: 0.3) : const Color(0xFFBFDBFE),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.balance_rounded,
                size: 40,
                color: Color(0xFF2E6FF2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('empty_decisions_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('empty_decisions_sub'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: secondaryTextColor,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('log_decision_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                DecisionFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
