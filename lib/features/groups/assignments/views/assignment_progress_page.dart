import '../widgets/assignment_decision_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/group_member_model.dart';
import '../../providers/groups_provider.dart';
import '../models/group_assignment_model.dart';
import '../providers/assignments_provider.dart';

/// Screen allowing Group Admins and Members to inspect real-time completion
/// progress for a specific Group Assignment.
///
/// TODO: In a future iteration, an edit/delete assignment flow could be added here.
class AssignmentProgressPage extends ConsumerWidget {
  final String groupId;
  final GroupAssignmentModel assignment;

  const AssignmentProgressPage({
    super.key,
    required this.groupId,
    required this.assignment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F5);

    // Watch real-time completions subcollection
    final completionsAsync = ref.watch(
      assignmentCompletionsStreamProvider(
        AssignmentRefParams(groupId: groupId, assignmentId: assignment.id),
      ),
    );

    // Watch group members for up-to-date member names
    final membersAsync = ref.watch(groupMembersStreamProvider(groupId));
    final membersMap = {
      for (final m in (membersAsync.value ?? <GroupMemberModel>[])) m.uid: m,
    };

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: primaryTextColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('assignment_progress_title'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
      ),
      body: completionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            context.tr('error'),
            style: TextStyle(color: secondaryTextColor),
          ),
        ),
        data: (completions) {
          final totalAssignees = assignment.assignedTo.length;
          final doneCount = completions.where((c) => c.isDone).length;
          final completionPercent = totalAssignees > 0
              ? (doneCount / totalAssignees).clamp(0.0, 1.0)
              : 0.0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssignmentDecisionPanel(
                  groupId: groupId,
                  assignmentId: assignment.id,
                ),
                // -------------------------------------------------------------
                // 1. ASSIGNMENT SUMMARY CARD
                // -------------------------------------------------------------
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.25)
                            : const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type Icon Indicator
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: assignment.isTask
                                  ? const Color(
                                      0xFF38BDF8,
                                    ).withValues(alpha: isDark ? 0.2 : 0.12)
                                  : const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: isDark ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Icon(
                                assignment.isTask
                                    ? Icons.task_alt_rounded
                                    : Icons.repeat_rounded,
                                color: assignment.isTask
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF10B981),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Assignment Title and Creator
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignment.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: primaryTextColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${context.tr('assigned_by')}: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    Text(
                                      assignment.createdByName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: brandPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Meta Chips Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Type Badge
                          _buildMetaChip(
                            label: assignment.isTask
                                ? context.tr('assignment_type_task')
                                : context.tr('assignment_type_habit'),
                            icon: assignment.isTask
                                ? Icons.task_alt_rounded
                                : Icons.repeat_rounded,
                            color: assignment.isTask
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF10B981),
                            isDark: isDark,
                          ),

                          // Mode Badge
                          _buildMetaChip(
                            label: assignment.isCountMode
                                ? '${context.tr('completion_mode_count')}: ${assignment.targetCount}'
                                : context.tr('completion_mode_simple'),
                            icon: assignment.isCountMode
                                ? Icons.pin_rounded
                                : Icons.check_circle_outline_rounded,
                            color: brandPrimary,
                            isDark: isDark,
                          ),

                          // Deadline / Start Date
                          if (assignment.deadline != null)
                            _buildMetaChip(
                              label: DateFormat.yMMMd().add_jm().format(
                                assignment.deadline!,
                              ),
                              icon: Icons.calendar_today_rounded,
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.tr('completion_progress'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                          ),
                          Text(
                            '$doneCount / $totalAssignees ${context.tr('done')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: doneCount == totalAssignees
                                  ? const Color(0xFF10B981)
                                  : brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: completionPercent,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(
                            doneCount == totalAssignees
                                ? const Color(0xFF10B981)
                                : brandPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // -------------------------------------------------------------
                // 2. MEMBER COMPLETION STATUS LIST
                // -------------------------------------------------------------
                Text(
                  context.tr('member_progress_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: assignment.assignedTo.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final uid = assignment.assignedTo[index];
                    final member = membersMap[uid];
                    final completion = completions
                        .where((c) => c.uid == uid)
                        .firstOrNull;

                    final isDone = completion?.isDone == true;
                    final memberName =
                        member?.name ?? completion?.memberName ?? 'Member';

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isDone
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : borderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Member Avatar
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                memberName.isNotEmpty
                                    ? memberName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: primaryTextColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Member Name
                          Expanded(
                            child: Text(
                              '$memberName${completion?.decision == 'rejected' ? ' • ${context.tr('rejected')}' : ''}${completion?.delayReason.isNotEmpty == true ? '\n${completion!.delayReason}' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Status Badge
                          _buildStatusBadge(
                            isDone: isDone,
                            isCountMode: assignment.isCountMode,
                            currentCount: completion?.currentCount ?? 0,
                            targetCount: assignment.targetCount ?? 0,
                            context: context,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetaChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isDone,
    required bool isCountMode,
    required int currentCount,
    required int targetCount,
    required BuildContext context,
    required bool isDark,
  }) {
    if (isDone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(
            0xFF10B981,
          ).withValues(alpha: isDark ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 5),
            Text(
              context.tr('done'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      );
    }

    final pendingLabel = isCountMode
        ? '${context.tr('pending_status')} ($currentCount/$targetCount)'
        : context.tr('pending_status');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 13,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 5),
          Text(
            pendingLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}
