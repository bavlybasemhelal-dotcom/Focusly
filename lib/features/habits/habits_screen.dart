import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/habits_provider.dart';
import 'widgets/add_edit_habit_sheet.dart';
import 'widgets/habit_card.dart';

/// Main Habits screen in Focusly.
///
/// Features a header summary stat row (Total Habits, Longest Streak, Total Days),
/// an interactive weekly check-in list, empty state, and Floating Action Button.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final habitsAsync = ref.watch(habitsStreamProvider);
    final stats = ref.watch(habitStatsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Aurora Background Blooms
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------------
                // 1. HEADER TITLE & SUBTITLE
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('habits'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('habits_subtitle'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      // Quick Add Mini Action
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF0F1B4C)
                              : Colors.white,
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE2E8F5),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.add_rounded,
                            color: brandPrimary,
                            size: 22,
                          ),
                          tooltip: context.tr('add_habit'),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const AddEditHabitSheet(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. HEADER STAT SUMMARY CHIPS
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      // Total Habits Stat Card
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          isDark: isDark,
                          title: context.tr('total_habits'),
                          value: stats.totalHabits.toString(),
                          icon: Icons.checklist_rtl_rounded,
                          accentColor: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Longest Streak Stat Card
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          isDark: isDark,
                          title: context.tr('longest_streak'),
                          value: '${stats.longestStreak}d',
                          icon: Icons.local_fire_department_rounded,
                          accentColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Total Streak Days Sum Stat Card
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          isDark: isDark,
                          title: context.tr('total_streak_days'),
                          value: '${stats.totalStreakDays}d',
                          icon: Icons.stars_rounded,
                          accentColor: const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // -------------------------------------------------------------
                // 3. HABITS LIST VIEW
                // -------------------------------------------------------------
                Expanded(
                  child: habitsAsync.when(
                    data: (habits) {
                      if (habits.isEmpty) {
                        return _buildEmptyState(context, isDark);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 90),
                        physics: const BouncingScrollPhysics(),
                        itemCount: habits.length,
                        itemBuilder: (context, index) {
                          final habit = habits[index];
                          return HabitCard(
                            key: ValueKey(habit.id),
                            habit: habit,
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => _buildEmptyState(context, isDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 4. FLOATING ACTION BUTTON (+) TO ADD HABIT
      // -----------------------------------------------------------------------
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient(context),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? AppColors.cyanElectric.withValues(alpha: 0.4)
                  : const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: 'habits_fab',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddEditHabitSheet(),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
          tooltip: context.tr('add_habit'),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : const Color(0xFF2E6FF2).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F1B4C), const Color(0xFF1E2958)]
                      : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFBFDBFE),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Text('🔥', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('no_habits_yet'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_habits_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddEditHabitSheet(),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                context.tr('add_habit'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final amberGlow = isDark
        ? AppColors.amberGold.withValues(alpha: 0.12)
        : const Color(0xFFFBBF24).withValues(alpha: 0.15);
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.12)
        : const Color(0xFF38BDF8).withValues(alpha: 0.15);

    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -90,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(shape: BoxShape.circle, color: amberGlow),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cyanGlow),
          ),
        ),
      ],
    );
  }
}
