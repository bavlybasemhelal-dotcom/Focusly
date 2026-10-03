import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/data/completion_ledger.dart';
import '../../productivity/services/trash_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../para/providers/para_provider.dart';
import '../models/category_model.dart';
import '../models/task_model.dart';
import '../providers/tasks_provider.dart';
import '../widgets/add_edit_task_sheet.dart';

/// The List View rendering filterable task cards with inline subtasks and actions.
class TasksListView extends ConsumerStatefulWidget {
  final List<TaskModel> tasks;

  const TasksListView({super.key, required this.tasks});

  @override
  ConsumerState<TasksListView> createState() => _TasksListViewState();
}

class _TasksListViewState extends ConsumerState<TasksListView> {
  final Set<String> _expandedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final borderColor = AppColors.border(context);

    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.value ?? TaskCategory.defaultCategories;

    // Filter tasks based on active category selection
    final filteredTasks = selectedCategory == 'all'
        ? widget.tasks
        : widget.tasks.where((t) => t.categoryId == selectedCategory).toList();

    return Column(
      children: [
        // ---------------------------------------------------------------------
        // 1. HORIZONTAL CATEGORY FILTER CHIPS ROW
        // ---------------------------------------------------------------------
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Row(
            children: [
              // "All" Filter Chip
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8.0),
                child: FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr('all_tasks')),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: selectedCategory == 'all'
                              ? Colors.white.withValues(alpha: 0.25)
                              : (isDark
                                    ? Colors.white12
                                    : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.tasks.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: selectedCategory == 'all'
                                ? Colors.white
                                : secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  selected: selectedCategory == 'all',
                  selectedColor: brandPrimary,
                  backgroundColor: isDark
                      ? const Color(0xFF08123A)
                      : Colors.white,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: selectedCategory == 'all'
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: selectedCategory == 'all'
                        ? Colors.white
                        : primaryTextColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selectedCategory == 'all'
                          ? brandPrimary
                          : borderColor,
                      width: 1.2,
                    ),
                  ),
                  onSelected: (_) {
                    ref
                        .read(selectedCategoryFilterProvider.notifier)
                        .setFilter('all');
                  },
                ),
              ),

              // Dynamic Category Chips
              ...categories.map((cat) {
                final isSelected = selectedCategory == cat.id;
                final count = widget.tasks
                    .where((t) => t.categoryId == cat.id)
                    .length;
                final catName = cat.isDefault
                    ? context.tr(cat.nameKey)
                    : cat.nameKey;

                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8.0),
                  child: FilterChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cat.color,
                      ),
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(catName),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    selected: isSelected,
                    selectedColor: cat.color,
                    backgroundColor: isDark
                        ? const Color(0xFF08123A)
                        : Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : primaryTextColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected ? cat.color : borderColor,
                        width: 1.2,
                      ),
                    ),
                    onSelected: (_) {
                      ref
                          .read(selectedCategoryFilterProvider.notifier)
                          .setFilter(cat.id);
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        // ---------------------------------------------------------------------
        // 2. TASKS LIST VIEW OR EMPTY STATE
        // ---------------------------------------------------------------------
        Expanded(
          child: filteredTasks.isEmpty
              ? _buildEmptyState(
                  context,
                  isDark,
                  primaryTextColor,
                  secondaryTextColor,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 80),
                  itemCount: filteredTasks.length,
                  itemBuilder: (context, index) {
                    final task = filteredTasks[index];
                    final isExpanded = _expandedTaskIds.contains(task.id);
                    final taskCategory = categories.firstWhere(
                      (c) => c.id == task.categoryId,
                      orElse: () => TaskCategory.defaultCategories.first,
                    );

                    return _buildTaskCard(
                      context: context,
                      task: task,
                      category: taskCategory,
                      isExpanded: isExpanded,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      borderColor: borderColor,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFF0F1B4C)
                    : AppColors.primaryBlue.withValues(alpha: 0.12),
                border: Border.all(
                  color: isDark
                      ? AppColors.cyanElectric.withValues(alpha: 0.3)
                      : const Color(0xFFBFDBFE),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 42,
                color: AppColors.brandPrimary(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('no_tasks_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('no_tasks_subtitle'),
              style: TextStyle(
                fontSize: 14,
                color: secondaryColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard({
    required BuildContext context,
    required TaskModel task,
    required TaskCategory category,
    required bool isExpanded,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
  }) {
    final catName = category.isDefault
        ? context.tr(category.nameKey)
        : category.nameKey;
    final isToday = DateUtils.isSameDay(task.date, DateTime.now());
    final dateLabel = isToday
        ? context.tr('today')
        : DateFormat.MMMd().format(task.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: task.done
              ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
              : borderColor,
          width: 1.2,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Main Task Row Container
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedTaskIds.remove(task.id);
                  } else {
                    _expandedTaskIds.add(task.id);
                  }
                });
              },
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Priority Color Accent Bar (Left)
                    Container(width: 5, color: task.priority.color),
                    const SizedBox(width: 10),

                    // Checkbox
                    Checkbox(
                      value: task.done,
                      activeColor: AppColors.brandPrimary(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFCBD5E1),
                        width: 1.5,
                      ),
                      onChanged: (_) {
                        ref
                            .read(tasksControllerProvider)
                            .toggleTaskDone(task, context);
                      },
                    ),

                    // Task Content Body
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Task Title
                            Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: task.done
                                    ? secondaryTextColor
                                    : primaryTextColor,
                                decoration: task.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Meta Badges (Category Chip, Time, Date, Subtasks)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Category Tag Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: category.color.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    catName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: category.color,
                                    ),
                                  ),
                                ),

                                // Date Badge
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: isToday
                                          ? AppColors.brandPrimary(context)
                                          : secondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isToday
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: isToday
                                            ? AppColors.brandPrimary(context)
                                            : secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),

                                // Time Badge (if set)
                                if (task.time != null) ...[
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: secondaryTextColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        task.time!.format(context),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryTextColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                // Subtasks Progress Counter Badge
                                if (task.subtasks.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white12
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.checklist_rounded,
                                          size: 12,
                                          color: secondaryTextColor,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${task.completedSubtasksCount}/${task.subtasks.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // PARA Project Chip (if task is linked to a Project)
                                if (task.projectId != null) ...[
                                  Consumer(
                                    builder: (context, ref, _) {
                                      final allProjectsAsync = ref.watch(
                                        allParaProjectsStreamProvider,
                                      );
                                      final project = allProjectsAsync.value
                                          ?.where((p) => p.id == task.projectId)
                                          .firstOrNull;
                                      if (project == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2E6FF2,
                                          ).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF2E6FF2,
                                            ).withValues(alpha: 0.3),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.folder_special_rounded,
                                              size: 10.5,
                                              color: Color(0xFF2E6FF2),
                                            ),
                                            const SizedBox(width: 3.5),
                                            Text(
                                              project.title,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2E6FF2),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],

                                // Group Assigned Badge
                                if (task.isGroupAssigned) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0284C7,
                                      ).withValues(alpha: isDark ? 0.22 : 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0284C7,
                                        ).withValues(alpha: 0.35),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.group_rounded,
                                          size: 10.5,
                                          color: Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          task.assignedByName != null &&
                                                  task
                                                      .assignedByName!
                                                      .isNotEmpty
                                              ? '${context.tr('assigned_by_badge')}: ${task.assignedByName}'
                                              : context.tr(
                                                  'group_assigned_badge',
                                                ),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions (Edit & Delete)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 19),
                      color: secondaryTextColor,
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => AddEditTaskSheet(taskToEdit: task),
                        );
                      },
                      tooltip: context.tr('edit_task'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                      color: AppColors.errorRed.withValues(alpha: 0.8),
                      onPressed: () => _confirmDeleteTask(context, task.id),
                      tooltip: context.tr('delete_task'),
                    ),
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // EXPANDED INLINE SECTION (Notes & Subtasks Checklist)
            // -----------------------------------------------------------------
            if (isExpanded) ...[
              Divider(height: 1, color: borderColor),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                color: isDark
                    ? const Color(0xFF08123A).withValues(alpha: 0.5)
                    : const Color(0xFFF8FAFC),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notes Section (if present)
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.notes!,
                              style: TextStyle(
                                fontSize: 13,
                                color: primaryTextColor.withValues(alpha: 0.85),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Subtasks Section Header
                    Text(
                      context.tr('subtasks'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: secondaryTextColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtasks Checklist Items
                    ...task.subtasks.map((subtask) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: subtask.done,
                                activeColor: AppColors.brandPrimary(context),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                                onChanged: (_) {
                                  ref
                                      .read(tasksControllerProvider)
                                      .toggleSubtask(task, subtask.id);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _showEditSubtaskDialog(
                                  context,
                                  task,
                                  subtask,
                                ),
                                child: Text(
                                  subtask.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: subtask.done
                                        ? secondaryTextColor
                                        : primaryTextColor,
                                    decoration: subtask.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 15),
                              color: secondaryTextColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: context.tr('edit_subtask'),
                              onPressed: () => _showEditSubtaskDialog(
                                context,
                                task,
                                subtask,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: secondaryTextColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ref
                                    .read(tasksControllerProvider)
                                    .deleteSubtask(task, subtask.id);
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 8),

                    // Inline "+ Add subtask" Field
                    _InlineAddSubtaskInput(task: task),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSubtaskDialog(
    BuildContext context,
    TaskModel task,
    SubtaskModel subtask,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final controller = TextEditingController(text: subtask.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: brandPrimary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('edit_subtask'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: primaryTextColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.tr('subtask_title_hint'),
              hintStyle: TextStyle(
                color: secondaryTextColor.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF08123A)
                  : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: brandPrimary, width: 1.5),
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                Navigator.of(dialogContext).pop(val.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                final val = controller.text.trim();
                if (val.isNotEmpty) {
                  Navigator.of(dialogContext).pop(val);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: brandPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(context.tr('save')),
            ),
          ],
        );
      },
    );

    if (newTitle != null &&
        newTitle.trim().isNotEmpty &&
        newTitle.trim() != subtask.title) {
      await ref
          .read(tasksControllerProvider)
          .editSubtask(task, subtask.id, newTitle.trim());
    }
  }

  Future<void> _confirmDeleteTask(BuildContext context, String taskId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.tr('delete_task_confirm_title'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          content: Text(context.tr('delete_task_confirm_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(context.tr('delete')),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      final account = ref.read(currentUserIdProvider);
      try {
        await ref.read(tasksControllerProvider).deleteTask(taskId);
        if (context.mounted &&
            account != null &&
            ref.read(currentUserIdProvider) == account) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('task_deleted')),
              action: SnackBarAction(
                label: context.tr('undo'),
                onPressed: () async {
                  try {
                    await TrashService(FirebaseFirestore.instance).restore(
                      account,
                      CompletionLedger.eventKey('tasks/$taskId'),
                    );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$error')));
                    }
                  }
                },
              ),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }
  }
}

/// Helper component providing inline input for adding subtasks
class _InlineAddSubtaskInput extends ConsumerStatefulWidget {
  final TaskModel task;

  const _InlineAddSubtaskInput({required this.task});

  @override
  ConsumerState<_InlineAddSubtaskInput> createState() =>
      _InlineAddSubtaskInputState();
}

class _InlineAddSubtaskInputState
    extends ConsumerState<_InlineAddSubtaskInput> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(tasksControllerProvider).addSubtask(widget.task, text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandPrimary = AppColors.brandPrimary(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary(context),
            ),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.tr('add_subtask_hint'),
              hintStyle: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context).withValues(alpha: 0.6),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: brandPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brandPrimary.withValues(alpha: 0.15),
            ),
            child: Icon(Icons.add_rounded, size: 16, color: brandPrimary),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: _submit,
        ),
      ],
    );
  }
}
