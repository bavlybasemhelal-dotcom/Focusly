import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/providers/tasks_provider.dart';

/// "Today's Focus" card for the Home Feed.
///
/// Surfaces up to 3 highest-priority incomplete tasks scheduled for today
/// with quick-complete checkboxes, reusing [tasksStreamProvider] and [tasksControllerProvider].
/// Hides itself entirely when zero tasks are scheduled for today.
class TodaysFocusCard extends ConsumerWidget {
  final VoidCallback onViewAll;

  const TodaysFocusCard({super.key, required this.onViewAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);

    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.value ?? <TaskModel>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter tasks that are incomplete and scheduled for today (or earlier / overdue)
    final todayIncompleteTasks = allTasks.where((t) {
      if (t.done) return false;
      final taskDate = DateTime(t.date.year, t.date.month, t.date.day);
      return taskDate.isBefore(today.add(const Duration(days: 1)));
    }).toList();

    // Respect the strict "hide when empty/irrelevant" rule
    if (todayIncompleteTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by priority (high first, then medium, low)
    todayIncompleteTasks.sort((a, b) {
      final aPriority = _priorityRank(a.priority);
      final bPriority = _priorityRank(b.priority);
      return aPriority.compareTo(bPriority);
    });

    final previewTasks = todayIncompleteTasks.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E6FF2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E6FF2),
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.tr('todays_focus_title'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // Task Count Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cyanElectric.withValues(alpha: 0.15)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.cyanElectric.withValues(alpha: 0.3)
                        : const Color(0xFFBFDBFE),
                    width: 1,
                  ),
                ),
                child: Text(
                  context.tr(
                    'tasks_left_today_badge',
                    args: {'count': todayIncompleteTasks.length.toString()},
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.cyanElectric
                        : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Compact Task Rows
          ...previewTasks.map((task) {
            final priorityColor = task.priority.color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Quick-Complete Checkbox
                    InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(tasksControllerProvider)
                            .toggleTaskDone(task, context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: priorityColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.circle,
                          size: 0,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Task Title & Time/Priority
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (task.time != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.time!.format(context),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Priority Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.priority.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // 3. View All Footer Link
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onViewAll();
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr('view_all_tasks'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: brandPrimary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _priorityRank(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 1;
      case TaskPriority.medium:
        return 2;
      case TaskPriority.low:
        return 3;
    }
  }
}
