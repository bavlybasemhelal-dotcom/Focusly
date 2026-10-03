import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'providers/workout_provider.dart';
import 'widgets/workout_card.dart';
import 'widgets/workout_form_modal.dart';
import 'widgets/workout_heatmap_widget.dart';

/// Main Workout Tracker screen displaying weekly stats, recent workouts, and 30-day streak heatmap.
class WorkoutTrackerPage extends ConsumerWidget {
  const WorkoutTrackerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    final recentWorkouts = ref.watch(recentWorkoutsProvider);
    final allWorkoutsAsync = ref.watch(workoutsStreamProvider);
    final stats = ref.watch(workoutStatsProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('workout_tracker_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            Text(
              context.tr('workout_tracker_subtitle'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Color(0xFF10B981),
            ),
            tooltip: context.tr('add_workout_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              WorkoutFormModal.show(context);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.fitness_center_rounded, size: 20),
        label: Text(
          context.tr('add_workout_btn'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          WorkoutFormModal.show(context);
        },
      ),
      body: allWorkoutsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              '${context.tr('error')}: $err',
              style: const TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ),
        data: (allWorkouts) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            physics: const BouncingScrollPhysics(),
            children: [
              // =======================================================
              // SECTION 1: STATS ROW (This Week Minutes & Calories)
              // =======================================================
              Row(
                children: [
                  // This Week Minutes Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            stats.thisWeekMinutes.toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('this_week_minutes_label'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // This Week Calories Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            stats.thisWeekCalories.toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E6FF2),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr('this_week_calories_label'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // =======================================================
              // SECTION 2: RECENT WORKOUTS (5 Most Recent)
              // =======================================================
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('recent_workouts_header'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (recentWorkouts.isEmpty)
                _buildEmptyWorkoutsState(
                  context,
                  primaryTextColor,
                  secondaryTextColor,
                )
              else
                ...recentWorkouts.map(
                  (workout) => WorkoutCard(workout: workout),
                ),

              const SizedBox(height: 24),

              // =======================================================
              // SECTION 3: LAST 30 DAYS STREAK HEATMAP
              // =======================================================
              const WorkoutHeatmapWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyWorkoutsState(
    BuildContext context,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.fitness_center_rounded,
                size: 30,
                color: Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('empty_workouts_title'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('empty_workouts_subtitle'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: secondaryTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              context.tr('add_workout_btn'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              WorkoutFormModal.show(context);
            },
          ),
        ],
      ),
    );
  }
}
