import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../helpers/streak_logic.dart';
import '../models/habit_model.dart';
import '../providers/habits_provider.dart';
import 'add_edit_habit_sheet.dart';

/// Interactive card component representing a Habit in the list.
///
/// Displays habit title, stack-trigger anchor cue, streak count with flame icon,
/// reminder time badge, and 7 tappable daily check-in pills with "today" indicator.
class HabitCard extends ConsumerWidget {
  final HabitModel habit;

  const HabitCard({super.key, required this.habit});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFE2E8F5),
            width: 1.2,
          ),
        ),
        title: Text(
          context.tr('delete_habit_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
            fontSize: 20,
          ),
        ),
        content: Text(
          context.tr('delete_habit_confirm_message'),
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(habitsControllerProvider).deleteHabit(habit.id, context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditHabitSheet(habitToEdit: habit),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    // Compute today's 0..6 index within the week based on habit's reset day
    final todayIndex = StreakLogic.getWeekDayIndex(
      DateTime.now(),
      weekStartDay: habit.resetDay,
    );

    final dayLabels = StreakLogic.getWeekDayLabels(
      isArabic: isArabic,
      weekStartDay: habit.resetDay,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Title, Stack Trigger, and Action Buttons (Edit / Delete)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Habit Fire / Check Indicator
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: habit.streak > 0
                      ? const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1E293B),
                                  const Color(0xFF0F172A),
                                ]
                              : [
                                  const Color(0xFFE2E8F0),
                                  const Color(0xFFCBD5E1),
                                ],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: habit.streak > 0
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    habit.streak > 0 ? '🔥' : '🌱',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Title and Stack Trigger Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (habit.stackTrigger != null &&
                        habit.stackTrigger!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.tips_and_updates_rounded,
                            size: 13,
                            color: Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              habit.stackTrigger!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF38BDF8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions: Edit and Delete
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: context.tr('edit'),
                    onPressed: () => _openEditSheet(context),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.errorRed,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: context.tr('delete'),
                    onPressed: () => _showDeleteConfirmation(context, ref),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Badges (Streak Count Pill & Reminder Time Chip)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              // Streak Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: habit.streak > 0
                      ? const Color(
                          0xFFF59E0B,
                        ).withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: habit.streak > 0
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                        : borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${habit.streak} ${context.tr('days_streak')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: habit.streak > 0
                            ? (isDark
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFD97706))
                            : secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Reminder Time Chip (if set)
              if (habit.time != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.alarm_rounded,
                        size: 13,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        habit.time!.format(context),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),

              // Group Assigned Badge
              if (habit.isGroupAssigned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFF0284C7,
                    ).withValues(alpha: isDark ? 0.22 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_rounded,
                        size: 13,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        habit.assignedByName != null &&
                                habit.assignedByName!.isNotEmpty
                            ? '${context.tr('assigned_by_badge')}: ${habit.assignedByName}'
                            : context.tr('group_assigned_badge'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // -------------------------------------------------------------------
          // Row 3: Count-Mode Progress Tracker vs 7-Day Week Grid
          // NOTE: Group-assigned habits with completionMode='count' bypass the
          // 7-day streak grid and display a running counter toward targetCount.
          // -------------------------------------------------------------------
          if (habit.isCountMode) ...[
            Builder(
              builder: (context) {
                final target = habit.targetCount ?? 1;
                final current = habit.currentCount;
                final isDone = current >= target || habit.isCompleted;
                final progress = (current / target).clamp(0.0, 1.0);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF08123A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : borderColor,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDone
                                    ? Icons.check_circle_rounded
                                    : Icons.track_changes_rounded,
                                size: 18,
                                color: isDone
                                    ? const Color(0xFF10B981)
                                    : brandPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDone
                                    ? context.tr('target_reached')
                                    : context.tr('target_progress'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDone
                                      ? const Color(0xFF10B981)
                                      : primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$current / $target',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDone
                                  ? const Color(0xFF10B981)
                                  : brandPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(
                            isDone ? const Color(0xFF10B981) : brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (current > 0)
                            IconButton(
                              onPressed: () {
                                ref
                                    .read(habitsControllerProvider)
                                    .decrementHabitCount(habit, context);
                              },
                              icon: const Icon(
                                Icons.remove_circle_outline_rounded,
                              ),
                              color: secondaryTextColor,
                              iconSize: 22,
                              tooltip: context.tr('decrement_count'),
                            ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: isDone
                                ? null
                                : () {
                                    ref
                                        .read(habitsControllerProvider)
                                        .incrementHabitCount(habit, context);
                                  },
                            icon: Icon(
                              isDone
                                  ? Icons.done_all_rounded
                                  : Icons.add_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isDone
                                  ? context.tr('done')
                                  : context.tr('log_habit_btn'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDone
                                  ? const Color(0xFF10B981)
                                  : brandPrimary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            // Row 3: 7 Interactive Day Check-in Cells
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (dayIdx) {
                final isDone = habit.isDayCompleted(dayIdx);
                final isToday = dayIdx == todayIndex;
                final label = dayLabels[dayIdx];

                return InkWell(
                  onTap: () {
                    ref
                        .read(habitsControllerProvider)
                        .toggleDay(habit, dayIdx, context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    width: 40,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isDone
                          ? AppColors.primaryGradient(context)
                          : null,
                      color: !isDone
                          ? (isDark
                                ? (isToday
                                      ? const Color(0xFF1E2958)
                                      : const Color(0xFF0A1238))
                                : (isToday
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF8FAFC)))
                          : null,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? Colors.transparent
                            : (isToday ? brandPrimary : borderColor),
                        width: isToday ? 1.8 : 1,
                      ),
                      boxShadow: isDone
                          ? [
                              BoxShadow(
                                color: isDark
                                    ? AppColors.cyanElectric.withValues(
                                        alpha: 0.35,
                                      )
                                    : const Color(
                                        0xFF2E6FF2,
                                      ).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Day Label (e.g. Sat / سبت)
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isDone
                                ? (isDark
                                      ? const Color(0xFF060B24)
                                      : Colors.white)
                                : (isToday ? brandPrimary : secondaryTextColor),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Check Icon or Empty Dot
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? (isDark
                                      ? const Color(0xFF060B24)
                                      : Colors.white)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: isDone
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 13,
                                    color: isDark
                                        ? AppColors.cyanElectric
                                        : brandPrimary,
                                  )
                                : (isToday
                                      ? Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: brandPrimary,
                                          ),
                                        )
                                      : const SizedBox.shrink()),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
