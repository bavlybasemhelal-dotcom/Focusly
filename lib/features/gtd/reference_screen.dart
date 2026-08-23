import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/models/task_model.dart';
import 'providers/gtd_provider.dart';
import 'services/gtd_service.dart';
import 'widgets/add_reference_sheet.dart';

/// GTD "Reference" screen.
///
/// Stores non-actionable knowledge, documents, snippets, and references.
/// Styled with lightweight visual tokens (no urgency, dates, or priority badges).
class ReferenceScreen extends ConsumerWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    final referenceTasksAsync = ref.watch(referenceTasksStreamProvider);

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
                              context.tr('reference_screen_title'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              context.tr('reference_screen_subtitle'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add Reference item button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () => AddReferenceSheet.show(context),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                          tooltip: context.tr('add_reference_title'),
                        ),
                      ),
                    ],
                  ),
                ),

                // -------------------------------------------------------------
                // 2. LIST OF REFERENCE ITEMS
                // -------------------------------------------------------------
                Expanded(
                  child: referenceTasksAsync.when(
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
                        itemCount: tasks.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return _buildReferenceCard(context, task, isDark, primaryTextColor, secondaryTextColor);
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

  Widget _buildReferenceCard(
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
            color: isDark ? Colors.black26 : const Color(0xFF38BDF8).withValues(alpha: 0.04),
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
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bookmark_outline_rounded, color: Color(0xFF38BDF8), size: 16),
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
                      const SizedBox(height: 6),
                      Text(
                        task.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => GTDService().deleteTask(task.id),
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                tooltip: context.tr('delete'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reference tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.tr('reference_tag'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF38BDF8),
              ),
            ),
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
                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('reference_empty_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('reference_empty_prompt'),
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
              onPressed: () => AddReferenceSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.tr('add_reference_title')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
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
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.1)
                    : const Color(0xFF38BDF8).withValues(alpha: 0.04),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
