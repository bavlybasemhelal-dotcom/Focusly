import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/task_model.dart';
import 'providers/tasks_provider.dart';
import 'views/eisenhower_matrix_view.dart';
import 'views/tasks_list_view.dart';
import 'widgets/add_edit_task_sheet.dart';

/// The main Tasks Screen containing the view mode switcher (List / Matrix),
/// task statistics summary, and floating action button.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final viewMode = ref.watch(tasksViewModeProvider);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final tasksList = tasksAsync.value ?? <TaskModel>[];

    final completedCount = tasksList.where((t) => t.done).length;
    final pendingCount = tasksList.length - completedCount;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient aurora bloom in background
          _buildAmbientGlowBlooms(isDark),

          SafeArea(
            child: Column(
              children: [
                // -------------------------------------------------------------
                // 1. TOP HEADER & VIEW MODE SEGMENTED TOGGLE
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Header Title & Counter Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('tasks'),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$pendingCount ${context.tr('tasks_pending')} • $completedCount ${context.tr('tasks_completed')}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),

                      // View Mode Switcher (List / Matrix)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFE2E8F5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // List View Button
                            _buildViewModeButton(
                              icon: Icons.view_list_rounded,
                              label: context.tr('list_view'),
                              isSelected: viewMode == TasksViewMode.list,
                              isDark: isDark,
                              brandPrimary: brandPrimary,
                              onTap: () {
                                ref.read(tasksViewModeProvider.notifier).setMode(
                                      TasksViewMode.list,
                                    );
                              },
                            ),
                            // Matrix View Button
                            _buildViewModeButton(
                              icon: Icons.grid_view_rounded,
                              label: context.tr('matrix_view'),
                              isSelected: viewMode == TasksViewMode.matrix,
                              isDark: isDark,
                              brandPrimary: brandPrimary,
                              onTap: () {
                                ref.read(tasksViewModeProvider.notifier).setMode(
                                      TasksViewMode.matrix,
                                    );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. ACTIVE VIEW (List View or Matrix View)
                // -------------------------------------------------------------
                Expanded(
                  child: viewMode == TasksViewMode.list
                      ? TasksListView(tasks: tasksList)
                      : EisenhowerMatrixView(tasks: tasksList),
                ),
              ],
            ),
          ),
        ],
      ),

      // -----------------------------------------------------------------------
      // 3. FLOATING ACTION BUTTON (+) TO ADD NEW TASK
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
          heroTag: 'tasks_fab',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddEditTaskSheet(),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: isDark ? const Color(0xFF060B24) : Colors.white,
          tooltip: context.tr('add_task'),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required Color brandPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF08123A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? brandPrimary : (isDark ? Colors.white60 : Colors.black45),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? brandPrimary : (isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlowBlooms(bool isDark) {
    final cyanGlow = isDark
        ? AppColors.cyanElectric.withValues(alpha: 0.14)
        : const Color(0xFF38BDF8).withValues(alpha: 0.18);
    final greenGlow = isDark
        ? AppColors.accentGreenNeon.withValues(alpha: 0.12)
        : const Color(0xFF34D399).withValues(alpha: 0.16);

    return Stack(
      children: [
        Positioned(
          top: -90,
          right: -90,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [cyanGlow, Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -70,
          left: -70,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [greenGlow, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
