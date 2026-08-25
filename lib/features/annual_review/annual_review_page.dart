import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_colors.dart';
import 'models/annual_review_model.dart';
import 'providers/annual_review_provider.dart';
import 'services/year_stats_calculator.dart';
import 'widgets/annual_review_form_modal.dart';

/// Main screen for Focusly's Annual Review feature, displaying yearly guided reflections
/// accompanied by an auto-computed live productivity stats dashboard.
class AnnualReviewPage extends ConsumerWidget {
  const AnnualReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    final reviewsAsync = ref.watch(annualReviewsStreamProvider);
    final reviews = reviewsAsync.value ?? <AnnualReviewModel>[];

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
              context.tr('annual_review_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('annual_review_subtitle'),
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
      body: reviewsAsync.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : reviews.isEmpty
              ? _buildEmptyState(context, isDark, primaryTextColor, secondaryTextColor)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                  physics: const BouncingScrollPhysics(),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return _buildReviewCard(
                      context: context,
                      ref: ref,
                      review: review,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          context.tr('start_annual_review_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          AnnualReviewFormModal.show(context);
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
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🗓️', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('annual_review_empty_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('annual_review_empty_subtitle'),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: Text(
                context.tr('start_annual_review_btn'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                AnnualReviewFormModal.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard({
    required BuildContext context,
    required WidgetRef ref,
    required AnnualReviewModel review,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final stats = ref.watch(yearStatsProvider(review.year));

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // Header Row: Year Title + Edit/Delete Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🗓️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    '${review.year}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: secondaryTextColor,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      AnnualReviewFormModal.show(context, reviewToEdit: review);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: const Color(0xFFEF4444),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDelete(context, ref, review),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4-Cell Stats Strip
          _buildStatsStrip(
            context: context,
            stats: stats,
            isDark: isDark,
            secondaryTextColor: secondaryTextColor,
          ),
          const SizedBox(height: 20),

          // 4 Reflection Question Answers
          _buildAnswerBlock(
            icon: '🏆',
            title: context.tr('review_q1_title'),
            content: review.q1,
            accentColor: const Color(0xFFF59E0B),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
          ),
          const SizedBox(height: 14),

          _buildAnswerBlock(
            icon: '🚧',
            title: context.tr('review_q2_title'),
            content: review.q2,
            accentColor: const Color(0xFFEF4444),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
          ),
          const SizedBox(height: 14),

          _buildAnswerBlock(
            icon: '🧠',
            title: context.tr('review_q3_title'),
            content: review.q3,
            accentColor: const Color(0xFF8B5CF6),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
          ),
          const SizedBox(height: 14),

          _buildAnswerBlock(
            icon: '🚀',
            title: context.tr('review_q4_title'),
            content: review.q4,
            accentColor: const Color(0xFF10B981),
            isDark: isDark,
            primaryTextColor: primaryTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsStrip({
    required BuildContext context,
    required YearStatsData stats,
    required bool isDark,
    required Color secondaryTextColor,
  }) {
    final stripBg = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: stripBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCell(
              label: context.tr('review_stat_workouts'),
              value: '${stats.workouts}',
              color: const Color(0xFF10B981),
              secondaryTextColor: secondaryTextColor,
            ),
          ),
          _buildDivider(isDark),
          Expanded(
            child: _buildStatCell(
              label: context.tr('review_stat_tasks'),
              value: '${stats.tasks}',
              color: const Color(0xFF00E5FF),
              secondaryTextColor: secondaryTextColor,
            ),
          ),
          _buildDivider(isDark),
          Expanded(
            child: _buildStatCell(
              label: context.tr('review_stat_books'),
              value: '${stats.books}',
              color: const Color(0xFFF59E0B),
              secondaryTextColor: secondaryTextColor,
            ),
          ),
          _buildDivider(isDark),
          Expanded(
            child: _buildStatCell(
              label: context.tr('review_stat_energy'),
              value: stats.formattedEnergy,
              color: const Color(0xFFF97316),
              secondaryTextColor: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required Color color,
    required Color secondaryTextColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: secondaryTextColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28,
      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
    );
  }

  Widget _buildAnswerBlock({
    required String icon,
    required String title,
    required String content,
    required Color accentColor,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Text(
              '$title:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: SelectableText(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, AnnualReviewModel review) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_review_dialog_title')),
        content: Text(
          context.tr(
            'delete_review_dialog_msg',
            args: {'year': review.year.toString()},
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
            child: Text(context.tr('delete_review_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        await ref.read(annualReviewServiceProvider).deleteReview(uid, review.id);
      }
    }
  }
}
