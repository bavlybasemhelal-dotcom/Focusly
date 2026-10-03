import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../para/providers/para_provider.dart';
import 'models/goal_model.dart';
import 'providers/goals_provider.dart';
import 'goal_sources_page.dart';
import 'widgets/circular_progress_ring.dart';
import 'widgets/goal_card.dart';
import 'widgets/goal_form_modal.dart';

/// Detailed view and interaction screen for a Goal.
class GoalDetailPage extends ConsumerWidget {
  final String goalId;
  final GoalModel? initialGoal;

  const GoalDetailPage({super.key, required this.goalId, this.initialGoal});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    GoalModel goal,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('delete_goal_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.tr('delete_goal_confirm_msg', args: {'title': goal.title}),
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await ref
            .read(goalsServiceProvider)
            .deleteGoal(uid: uid, goalId: goal.id);
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('goal_deleted_toast')),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    // Listen to goals list stream to get live goal state
    final goalsAsync = ref.watch(goalsStreamProvider);
    final allGoals = goalsAsync.value ?? [];
    final goal =
        allGoals.where((g) => g.id == goalId).firstOrNull ?? initialGoal;

    if (goal == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            context.tr('goal_not_found'),
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
      );
    }

    final baseColor = parseGoalColor(goal.color);
    final isDone = goal.isDone;

    // Look up linked area
    final areasAsync = ref.watch(paraAreasStreamProvider);
    final areas = areasAsync.value ?? [];
    final linkedArea = goal.areaId != null
        ? areas.where((a) => a.id == goal.areaId).firstOrNull
        : null;

    final targetDateDisplay = goal.targetDate != null
        ? DateFormat.yMMMMd().format(goal.targetDate!)
        : null;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('goal_details_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        actions: [
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'ar'
                ? 'مصادر التقدم'
                : 'Progress sources',
            icon: const Icon(Icons.account_tree_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GoalSourcesPage(goalId: goal.id),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            color: const Color(0xFF2E6FF2),
            onPressed: () => GoalFormModal.show(context, goal: goal),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: AppColors.errorRed),
            onPressed: () => _confirmDelete(context, ref, goal),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Radiant Goal Header Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    baseColor,
                    Color.lerp(baseColor, Colors.black, isDark ? 0.45 : 0.25) ??
                        baseColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withValues(alpha: isDark ? 0.35 : 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji Box
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            goal.icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Title & Timeframe Chip
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.white70,
                                decorationThickness: 2.0,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.tr('timeframe_${goal.timeframe}'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Progress Ring
                      CircularProgressRing(
                        size: 58,
                        strokeWidth: 5.5,
                        progress: goal.effectiveProgress,
                        progressColor: Colors.white,
                        trackColor: Colors.white.withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Metadata Badges Row: Area + Target Date
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (linkedArea != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                linkedArea.emoji,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                linkedArea.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (targetDateDisplay != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                targetDateDisplay,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Mark Done / Restore Action Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.pending_outlined,
                    color: isDone
                        ? const Color(0xFF10B981)
                        : const Color(0xFF2E6FF2),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDone
                              ? context.tr('goal_completed_title')
                              : context.tr('goal_in_progress_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          isDone
                              ? context.tr('goal_completed_desc')
                              : context.tr('goal_in_progress_desc'),
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final uid = ref.read(currentUserIdProvider);
                      if (uid != null) {
                        final newStatus = isDone ? 'active' : 'done';
                        await ref
                            .read(goalsServiceProvider)
                            .setGoalStatus(
                              uid: uid,
                              goalId: goal.id,
                              status: newStatus,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newStatus == 'done'
                                    ? context.tr(
                                        'goal_completed_toast',
                                        args: {'title': goal.title},
                                      )
                                    : context.tr(
                                        'goal_restored_toast',
                                        args: {'title': goal.title},
                                      ),
                              ),
                              backgroundColor: newStatus == 'done'
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2E6FF2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDone
                          ? const Color(0xFF2E6FF2)
                          : const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isDone
                          ? context.tr('restore_goal_btn')
                          : context.tr('mark_done_goal_btn'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Milestones Checklist Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('milestones_checklist_header'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  '${goal.completedMilestonesCount}/${goal.milestones.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E6FF2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (goal.milestones.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text('🎯', style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('no_milestones_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_milestones_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              )
            else
              ...goal.milestones.asMap().entries.map((entry) {
                final index = entry.key;
                final milestone = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: milestone.done
                          ? const Color(0xFF10B981).withValues(alpha: 0.35)
                          : borderColor,
                    ),
                  ),
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final uid = ref.read(currentUserIdProvider);
                      if (uid != null) {
                        final willBeDone = !milestone.done;
                        await ref
                            .read(goalsServiceProvider)
                            .toggleMilestone(
                              uid: uid,
                              goalId: goal.id,
                              milestoneIndex: index,
                            );
                        if (willBeDone && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.tr(
                                  'milestone_completed_toast',
                                  args: {'title': milestone.title},
                                ),
                              ),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Row(
                      children: [
                        Icon(
                          milestone.done
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: milestone.done
                              ? const Color(0xFF10B981)
                              : secondaryTextColor,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            milestone.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                              decoration: milestone.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
