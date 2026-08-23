import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/models/task_model.dart';
import 'providers/gtd_provider.dart';
import 'services/gtd_service.dart';
import 'widgets/add_someday_sheet.dart';

/// GTD "Someday / Maybe" screen.
///
/// Holds aspirations, bucket-list items, and future ideas.
/// Features a periodic review reminder banner (anticipating future Weekly Review feature)
/// and direct task promotion.
class SomedayScreen extends ConsumerWidget {
  const SomedayScreen({super.key});

  Future<void> _handlePromoteToTask(BuildContext context, TaskModel task) async {
    HapticFeedback.mediumImpact();

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (date != null) {
      await GTDService().promoteSomedayToTask(
        task.id,
        newDate: date,
        priority: TaskPriority.medium,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(context.tr('someday_promoted_toast')),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF2E6FF2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    final somedayTasksAsync = ref.watch(somedayTasksStreamProvider);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          _buildAmbientGlow(isDark),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -------------------------------------------------------------
                // 1. SCREEN HEADER
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('someday_screen_title'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              context.tr('someday_screen_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add Someday item button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => AddSomedaySheet.show(context),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          tooltip: context.tr('add_someday_title'),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. PERIODIC REVIEW NUDGE BANNER
                // -------------------------------------------------------------
                // TODO: Connect this banner directly to the upcoming Weekly Review module
                // where Someday/Maybe items are systematically audited every 7 days.
                somedayTasksAsync.maybeWhen(
                  data: (tasks) {
                    if (tasks.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr('someday_review_nudge', args: {'count': tasks.length.toString()}),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),

                // -------------------------------------------------------------
                // 3. LIST OF SOMEDAY ITEMS
                // -------------------------------------------------------------
                Expanded(
                  child: somedayTasksAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text(
                        context.tr('tasks_load_error'),
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ),
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return _buildEmptyState(context, isDark, primaryTextColor, secondaryTextColor);
                      }

                      return ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 90),
                        itemCount: tasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildSomedayCard(context, task, isDark, primaryTextColor, secondaryTextColor);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSomedayCard(
    BuildContext context,
    TaskModel task,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F5);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0xFF8B5CF6).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.nightlight_round, color: Color(0xFF8B5CF6), size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        height: 1.3,
                      ),
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: secondaryTextColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (value) async {
                  if (value == 'promote') {
                    await _handlePromoteToTask(context, task);
                  } else if (value == 'delete') {
                    await GTDService().deleteTask(task.id);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'promote',
                    child: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, size: 18, color: Color(0xFF2E6FF2)),
                        const SizedBox(width: 8),
                        Text(ctx.tr('promote_to_task')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        const SizedBox(width: 8),
                        Text(ctx.tr('delete'), style: const TextStyle(color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Someday tag & Promote Action Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.tr('someday_tag'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _handlePromoteToTask(context, task),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF08123A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.rocket_launch_rounded, size: 13, color: Color(0xFF2E6FF2)),
                      const SizedBox(width: 5),
                      Text(
                        context.tr('promote_to_task'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E6FF2),
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
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.nightlight_outlined, size: 48, color: Color(0xFF8B5CF6)),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('someday_empty_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('someday_empty_prompt'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => AddSomedaySheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('add_someday_title')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(bool isDark) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                    : const Color(0xFF8B5CF6).withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
