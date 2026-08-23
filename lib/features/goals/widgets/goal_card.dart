import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../para/providers/para_provider.dart';
import '../goal_detail_page.dart';
import '../models/goal_model.dart';
import '../providers/goals_provider.dart';
import 'circular_progress_ring.dart';
import 'goal_form_modal.dart';

/// Parses a hex color string (e.g. '#2563EB' or '2563EB') into a Flutter [Color].
Color parseGoalColor(String? hexString, {Color fallback = const Color(0xFF2563EB)}) {
  if (hexString == null || hexString.isEmpty) return fallback;
  try {
    final clean = hexString.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return fallback;
}

/// Visual card representing a single Goal on the Life Map board.
class GoalCard extends ConsumerWidget {
  final GoalModel goal;

  const GoalCard({
    super.key,
    required this.goal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = parseGoalColor(goal.color);
    final isDone = goal.isDone;

    // Gradient colors based on goal color
    final gradientColors = isDone
        ? [
            baseColor.withValues(alpha: isDark ? 0.35 : 0.45),
            baseColor.withValues(alpha: isDark ? 0.15 : 0.25),
          ]
        : [
            baseColor,
            Color.lerp(baseColor, Colors.black, isDark ? 0.4 : 0.2) ?? baseColor,
          ];

    // Find linked Area name and emoji if set
    final areasAsync = ref.watch(paraAreasStreamProvider);
    final areas = areasAsync.value ?? [];
    final linkedArea = goal.areaId != null
        ? areas.where((a) => a.id == goal.areaId).firstOrNull
        : null;

    // Days remaining text & badge
    String? daysRemainingText;
    Color daysBadgeColor = Colors.white.withValues(alpha: 0.2);
    if (goal.targetDate != null) {
      final days = daysUntilDate(goal.targetDate!);
      if (days > 0) {
        daysRemainingText = '$days ${context.tr('days_left_suffix')}';
      } else if (days == 0) {
        daysRemainingText = context.tr('due_today_label');
        daysBadgeColor = const Color(0xFFF59E0B).withValues(alpha: 0.35);
      } else {
        daysRemainingText = context.tr('overdue_ended_label');
        daysBadgeColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDone
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: isDark ? 0.22 : 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: isDone ? 0.08 : (isDark ? 0.3 : 0.2)),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GoalDetailPage(goalId: goal.id, initialGoal: goal),
              ),
            );
          },
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Emoji Icon + Title + Progress Ring
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Goal Emoji Box
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Text(goal.icon, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Strikethrough if done
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: Colors.white70,
                              decorationThickness: 2.0,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isDone) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    context.tr('status_done_badge'),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Circular Progress Ring
                    CircularProgressRing(
                      size: 46,
                      strokeWidth: 4.2,
                      progress: goal.effectiveProgress,
                      progressColor: Colors.white,
                      trackColor: Colors.white.withValues(alpha: 0.22),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Middle: Linked Area and Milestones Chip
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (linkedArea != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(linkedArea.emoji, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Text(
                              linkedArea.title,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (goal.milestones.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checklist_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${goal.completedMilestonesCount}/${goal.milestones.length} ${context.tr('milestones_unit')}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (daysRemainingText != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: daysBadgeColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule_rounded, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              daysRemainingText,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Row: Quick Action Buttons (Edit + Mark Done / Restore)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Edit Icon Button
                    InkWell(
                      onTap: () => GoalFormModal.show(context, goal: goal),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Mark Done / Restore Button
                    InkWell(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        final uid = ref.read(currentUserIdProvider);
                        if (uid != null) {
                          final newStatus = isDone ? 'active' : 'done';
                          await ref.read(goalsServiceProvider).setGoalStatus(
                                uid: uid,
                                goalId: goal.id,
                                status: newStatus,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  newStatus == 'done'
                                      ? context.tr('goal_completed_toast', args: {'title': goal.title})
                                      : context.tr('goal_restored_toast', args: {'title': goal.title}),
                                ),
                                backgroundColor: newStatus == 'done'
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2E6FF2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDone
                              ? Colors.white.withValues(alpha: 0.2)
                              : const Color(0xFF10B981).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDone ? Icons.undo_rounded : Icons.check_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isDone
                                  ? context.tr('restore_goal_btn')
                                  : context.tr('mark_done_goal_btn'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
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
        ),
      ),
    );
  }
}
