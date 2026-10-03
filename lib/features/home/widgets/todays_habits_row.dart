import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../habits/models/habit_model.dart';
import '../../habits/providers/habits_provider.dart';
import '../../habits/helpers/streak_logic.dart';
import '../../../core/data/calendar_clock.dart';

/// Horizontal scroll row of today's habits for the Home Feed.
///
/// Surfaces active habits with streak counts and tap-to-toggle checkboxes,
/// reusing [habitsStreamProvider] and [habitsControllerProvider].
/// Hides itself entirely when zero habits exist.
class TodaysHabitsRow extends ConsumerWidget {
  const TodaysHabitsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);

    final habitsAsync = ref.watch(habitsStreamProvider);
    final habits = habitsAsync.value ?? <HabitModel>[];

    // Respect the strict "hide when empty/irrelevant" rule
    if (habits.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = ref.watch(calendarClockProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                context.tr('todays_habits_title'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final habit = habits[index];
              final todayDayIndex = StreakLogic.getWeekDayIndex(
                now,
                weekStartDay: habit.resetDay,
              );
              final isCompletedToday = habit.isDayCompleted(todayDayIndex);

              return Container(
                width: 170,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCompletedToday
                      ? (isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                            : const Color(0xFFECFDF5))
                      : cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isCompletedToday
                        ? (isDark
                              ? const Color(0xFF10B981)
                              : const Color(0xFF6EE7B7))
                        : borderColor,
                    width: isCompletedToday ? 1.4 : 1.2,
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(
                              0xFF2E6FF2,
                            ).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Quick Toggle Checkbox
                    InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(habitsControllerProvider)
                            .toggleDay(habit, todayDayIndex, context);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompletedToday
                              ? const Color(0xFF10B981)
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFF1F5F9)),
                          border: Border.all(
                            color: isCompletedToday
                                ? const Color(0xFF10B981)
                                : (isDark
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1)),
                            width: 1.5,
                          ),
                        ),
                        child: isCompletedToday
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Title & Streak
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            habit.title,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isCompletedToday
                                  ? (isDark
                                        ? Colors.white
                                        : const Color(0xFF065F46))
                                  : primaryTextColor,
                              decoration: isCompletedToday
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '🔥 ${habit.streak}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
