import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../models/learning_path_model.dart';
import '../providers/learning_paths_provider.dart';
import 'path_form_modal.dart';
import 'path_step_row.dart';

/// Card widget representing an entire learning path with progress and expandable day breakdown.
class PathCard extends ConsumerWidget {
  final LearningPathModel path;

  const PathCard({
    super.key,
    required this.path,
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
                dialogCtx.tr('delete_path_confirm_title'),
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
            'delete_path_confirm_msg',
            args: {'title': path.title},
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

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        final service = ref.read(learningPathsServiceProvider);
        await service.deletePath(uid: uid, pathId: path.id);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('path_deleted_toast')),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

    final expandedIds = ref.watch(expandedPathIdsProvider);
    final isExpanded = expandedIds.contains(path.id);

    final pct = path.progressPercent;
    final isDone = path.isFullyCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDone
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : borderColor,
          width: 1.2,
        ),
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
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Actions
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDone ? Icons.check_circle_rounded : Icons.alt_route_rounded,
                        size: 20,
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFF2E6FF2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        path.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: primaryTextColor,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Edit Action
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: secondaryTextColor,
                      tooltip: context.tr('edit_path_title'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        PathFormModal.show(context, pathToEdit: path);
                      },
                    ),
                    const SizedBox(width: 4),

                    // Delete Action
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: const Color(0xFFEF4444),
                      tooltip: context.tr('delete'),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Progress Bar & Day Stats
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100.0,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDone ? const Color(0xFF10B981) : const Color(0xFF2E6FF2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Progress Text & Expand Chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr(
                        'days_completed_progress',
                        args: {
                          'completed': path.progressDay.toString(),
                          'total': path.totalDays.toString(),
                          'percent': pct.toString(),
                        },
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDone ? const Color(0xFF10B981) : secondaryTextColor,
                      ),
                    ),

                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(expandedPathIdsProvider.notifier)
                            .toggleExpanded(path.id);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              isExpanded
                                  ? context.tr('collapse_curriculum')
                                  : context.tr('expand_curriculum'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E6FF2),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: const Color(0xFF2E6FF2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Expanded Day-by-Day Breakdown List
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: path.steps.map((step) {
                  return PathStepRow(
                    path: path,
                    step: step,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
