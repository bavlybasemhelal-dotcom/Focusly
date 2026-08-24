import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/retrospective_model.dart';
import '../providers/retrospective_provider.dart';
import 'retrospective_form_modal.dart';

/// Card widget displaying an individual Project Retrospective.
///
/// Features:
/// 1. Linked PARA Project Title (📁) with fallback to "General / Unknown Project".
/// 2. Localized Date header.
/// 3. Inset panel: 🟢 What went well?
/// 4. Inset panel: 🔴 What needs improvement?
/// 5. Inset panel: 🧠 Lessons learned & next steps.
/// 6. Edit & Delete action buttons with confirmation dialog.
class RetrospectiveCard extends ConsumerWidget {
  final RetrospectiveModel retrospective;

  const RetrospectiveCard({
    super.key,
    required this.retrospective,
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
                dialogCtx.tr('delete_retrospective_confirm_title'),
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
          dialogCtx.tr('delete_retrospective_confirm_msg'),
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
        final service = ref.read(retrospectiveServiceProvider);
        await service.deleteRetrospective(
          uid: uid,
          retrospectiveId: retrospective.id,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('retrospective_deleted_toast')),
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
    final dateStr = loc.formatLocalizedDate(retrospective.date);

    // Resolve project title
    final resolvedProjectTitle = ref.watch(
      projectTitleResolverProvider(retrospective.projectId),
    );
    final projectTitle = resolvedProjectTitle ?? context.tr('unknown_project_fallback');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
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
            // 1. Top Row: Project Badge & Actions (Edit / Delete)
            Row(
              children: [
                // Project Folder Badge
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.folder_special_rounded,
                          size: 16,
                          color: Color(0xFF2E6FF2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          projectTitle,
                          style: TextStyle(
                            fontSize: 16,
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
                ),

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
                    RetrospectiveFormModal.show(
                      context,
                      retrospectiveToEdit: retrospective,
                    );
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
            const SizedBox(height: 14),

            // 2. Inset Panel: 🟢 What went well?
            _buildInsetBlock(
              context: context,
              label: context.tr('went_well_label'),
              labelColor: const Color(0xFF10B981),
              content: retrospective.wentWell,
              bgColor: isDark
                  ? const Color(0xFF06281E).withValues(alpha: 0.5)
                  : const Color(0xFFF0FDF4),
              borderColor: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),

            // 3. Inset Panel: 🔴 What needs improvement?
            _buildInsetBlock(
              context: context,
              label: context.tr('to_improve_label'),
              labelColor: const Color(0xFFEF4444),
              content: retrospective.toImprove,
              bgColor: isDark
                  ? const Color(0xFF2E0D14).withValues(alpha: 0.5)
                  : const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),

            // 4. Inset Panel: 🧠 Lessons learned & next steps
            _buildInsetBlock(
              context: context,
              label: context.tr('learnings_label'),
              labelColor: const Color(0xFF2E6FF2),
              content: retrospective.learnings,
              bgColor: insetBg,
              borderColor: const Color(0xFF2E6FF2).withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsetBlock({
    required BuildContext context,
    required String label,
    required Color labelColor,
    required String content,
    required Color bgColor,
    required Color borderColor,
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
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: labelColor,
              letterSpacing: 0.2,
            ),
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
