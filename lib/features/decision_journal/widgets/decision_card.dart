import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/decision_model.dart';
import '../providers/decision_journal_provider.dart';
import 'decision_form_modal.dart';

/// Card widget displaying a single decision log with status badge,
/// rationale & expected outcome insets, actual outcome or review action button,
/// and edit/delete controls.
class DecisionCard extends ConsumerWidget {
  final DecisionModel decision;

  const DecisionCard({
    super.key,
    required this.decision,
  });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                dialogCtx.tr('delete_decision_confirm_title'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          dialogCtx.tr(
            'delete_decision_confirm_msg',
            args: {'title': decision.title},
          ),
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        final service = ref.read(decisionJournalServiceProvider);
        await service.deleteDecision(uid: uid, decisionId: decision.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('decision_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final insetBg = isDark ? const Color(0xFF08123A) : const Color(0xFFF8FAFC);

    final loc = AppLocalizations.of(context);
    final dateStr = loc.formatLocalizedDate(decision.date);

    // Status colors
    final isReviewed = decision.reviewed;
    final statusColor = isReviewed ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusText = isReviewed
        ? context.tr('status_reviewed')
        : context.tr('status_pending_review');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReviewed
              ? const Color(0xFF10B981).withValues(alpha: 0.25)
              : borderColor,
          width: 1.2,
        ),
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
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Status Badge + Date + Actions (Edit & Delete)
            Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),

                // Date Label
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(width: 8),

                // Edit Action
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    DecisionFormModal.show(context, decisionToEdit: decision);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Delete Action
                InkWell(
                  onTap: () => _confirmDelete(context, ref),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Decision Title
            Text(
              decision.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),

            // 3. Rationale Inset Panel
            _buildInsetBlock(
              context: context,
              label: context.tr('rationale_label'),
              icon: Icons.lightbulb_outline_rounded,
              iconColor: const Color(0xFF2E6FF2),
              content: decision.rationale,
              bgColor: insetBg,
              borderColor: borderColor,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // 4. Expected Outcome Inset Panel
            _buildInsetBlock(
              context: context,
              label: context.tr('expected_outcome_label'),
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF8B5CF6),
              content: decision.expected,
              bgColor: insetBg,
              borderColor: borderColor,
              isDark: isDark,
            ),
            const SizedBox(height: 10),

            // 5. Actual Outcome Inset Panel OR Evaluate & Review CTA Button
            if (isReviewed && decision.outcome.isNotEmpty) ...[
              _buildInsetBlock(
                context: context,
                label: context.tr('actual_outcome_label'),
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF10B981),
                content: decision.outcome,
                bgColor: isDark
                    ? const Color(0xFF06281E).withValues(alpha: 0.6)
                    : const Color(0xFFF0FDF4),
                borderColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                isDark: isDark,
              ),
            ] else ...[
              // CTA Button: Evaluate & Review Decision
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  DecisionFormModal.show(
                    context,
                    decisionToEdit: decision,
                    focusOutcome: true,
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                              const Color(0xFF0D9488).withValues(alpha: 0.4),
                            ]
                          : [
                              const Color(0xFFEFF6FF),
                              const Color(0xFFECFDF5),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.rate_review_outlined,
                        size: 18,
                        color: Color(0xFF2E6FF2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('evaluate_and_review_btn'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6FF2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Helper building a styled inset content block (e.g. for Rationale or Predictions).
  Widget _buildInsetBlock({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required String content,
    required Color bgColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final primaryTextColor = AppColors.textPrimary(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: primaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
