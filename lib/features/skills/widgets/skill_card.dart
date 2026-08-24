import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../tasks/models/category_model.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/skill_model.dart';
import 'skill_form_modal.dart';
import 'skill_quick_update_dialog.dart';
import 'sparkline_widget.dart';

/// Card widget representing an individual skill with its level, XP bar, 7-day sparkline, and actions.
class SkillCard extends ConsumerWidget {
  final SkillModel skill;

  const SkillCard({
    super.key,
    required this.skill,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final skillColor = Color(skill.color);

    // Resolve category name from categoriesProvider
    final categories = ref.watch(categoriesProvider).value ?? [];
    final categoryObj = categories.firstWhere(
      (c) => c.id == skill.category,
      orElse: () => TaskCategory.defaultCategories.first,
    );
    final categoryName = context.tr(categoryObj.nameKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Colored left accent bar
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: skillColor),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category Chip, Title, Level Badge, and Action Buttons
                  Row(
                    children: [
                      // Skill Name & Category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: skillColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.folder_special_rounded, size: 12, color: skillColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        categoryName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: skillColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              skill.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: primaryTextColor,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Level Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: skillColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: skillColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '${context.tr('level_prefix')} ${skill.level}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: skillColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // ⚡ Quick Update Button
                      IconButton(
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        color: const Color(0xFFF59E0B),
                        tooltip: context.tr('quick_update_skill_title'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          SkillQuickUpdateDialog.show(context, skill);
                        },
                      ),

                      // ✏️ Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        color: secondaryTextColor,
                        tooltip: context.tr('edit_skill_title'),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          SkillFormModal.show(context, skillToEdit: skill);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Middle Row: XP Progress Bar & 7-Day Sparkline
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // XP Progress Bar
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.tr('next_level_label'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                Text(
                                  '${skill.xp} / 100 XP',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: skillColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: skill.xpProgress,
                                minHeight: 6,
                                backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(skillColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 7-day sparkline
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            context.tr('sparkline_7d_label'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: secondaryTextColor.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          SparklineWidget(
                            history: skill.history,
                            color: skillColor,
                            width: 80,
                            height: 28,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
