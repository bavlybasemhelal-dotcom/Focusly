import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/models/task_model.dart';
import '../tasks/providers/tasks_provider.dart';
import '../tasks/widgets/add_edit_task_sheet.dart';
import 'models/para_area_model.dart';
import 'models/para_project_model.dart';
import 'providers/para_provider.dart';
import 'widgets/add_edit_project_sheet.dart';

/// Screen displaying active PARA Projects with linked Area badges, deadlines, and task previews.
class ProjectsPage extends ConsumerStatefulWidget {
  final String? initialFilterAreaId;

  const ProjectsPage({super.key, this.initialFilterAreaId});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  String? _selectedFilterAreaId;
  final Set<String> _expandedProjectIds = {};

  @override
  void initState() {
    super.initState();
    _selectedFilterAreaId = widget.initialFilterAreaId;
  }

  Future<void> _handleArchiveProject(ParaProjectModel project) async {
    HapticFeedback.lightImpact();
    await ref
        .read(paraServiceProvider)
        .setProjectArchived(project.id, archived: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('project_archived_toast')),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleDeleteProject(ParaProjectModel project) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          context.tr('delete_project_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        content: Text(
          context.tr(
            'delete_project_confirm_msg',
            args: {'title': project.title},
          ),
          style: TextStyle(color: secondaryTextColor, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.tr('delete_group_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(paraServiceProvider).deleteProject(project.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('project_deleted_toast')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  String _formatRelativeDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(deadline.year, deadline.month, deadline.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays < 0) {
      return context.tr(
        'deadline_overdue',
        args: {'days': (-diffDays).toString()},
      );
    } else if (diffDays == 0) {
      return context.tr('deadline_today');
    } else if (diffDays == 1) {
      return context.tr('deadline_tomorrow');
    } else {
      return context.tr(
        'deadline_in_days',
        args: {'days': diffDays.toString()},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final scaffoldBg = isDark
        ? const Color(0xFF070D28)
        : const Color(0xFFF8FAFC);

    final projectsAsync = ref.watch(paraProjectsStreamProvider);
    final areasAsync = ref.watch(paraAreasStreamProvider);

    final areasList = areasAsync.value ?? [];
    final Map<String, ParaAreaModel> areaMap = {
      for (final a in areasList) a.id: a,
    };

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('para_projects_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => AddEditProjectSheet.show(
                  context,
                  initialAreaId: _selectedFilterAreaId,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('add_project_btn')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: projectsAsync.when(
        data: (projects) {
          // Filter by area if selected
          final filteredProjects = _selectedFilterAreaId == null
              ? projects
              : projects
                    .where((p) => p.areaId == _selectedFilterAreaId)
                    .toList();

          return Column(
            children: [
              // Area Filter Chips Row (if areas exist)
              if (areasList.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildAreaFilterChip(
                          label: context.tr('all_areas_filter'),
                          isSelected: _selectedFilterAreaId == null,
                          onTap: () =>
                              setState(() => _selectedFilterAreaId = null),
                          isDark: isDark,
                          brandPrimary: brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        ...areasList.map((area) {
                          final isSelected = _selectedFilterAreaId == area.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildAreaFilterChip(
                              label: '${area.emoji} ${area.title}',
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedFilterAreaId = isSelected
                                      ? null
                                      : area.id;
                                });
                              },
                              isDark: isDark,
                              brandPrimary: brandPrimary,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              // Main Projects List
              Expanded(
                child: filteredProjects.isEmpty
                    ? _buildEmptyState(
                        context,
                        isDark,
                        primaryTextColor,
                        secondaryTextColor,
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
                        itemCount: filteredProjects.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final project = filteredProjects[index];
                          final linkedArea = areaMap[project.areaId];
                          final isExpanded = _expandedProjectIds.contains(
                            project.id,
                          );
                          final linkedTasks = ref.watch(
                            projectTasksProvider(project.id),
                          );

                          return _buildProjectCard(
                            context,
                            project,
                            linkedArea,
                            linkedTasks,
                            isExpanded,
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                            brandPrimary,
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            context.tr('projects_load_error'),
            style: const TextStyle(color: AppColors.errorRed),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color brandPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? brandPrimary
              : (isDark ? const Color(0xFF0F1B4C) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? brandPrimary
                : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : const Color(0xFFE2E8F5)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    ParaProjectModel project,
    ParaAreaModel? linkedArea,
    List<TaskModel> linkedTasks,
    bool isExpanded,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color brandPrimary,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    final bool isOverdue =
        project.deadline != null &&
        DateTime.now().isAfter(project.deadline!) &&
        !DateUtils.isSameDay(DateTime.now(), project.deadline!);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2E6FF2).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Area Badge + Actions Menu
                Row(
                  children: [
                    if (linkedArea != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF2E6FF2,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              linkedArea.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              linkedArea.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E6FF2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: secondaryTextColor,
                        size: 22,
                      ),
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (val) {
                        if (val == 'edit') {
                          AddEditProjectSheet.show(context, project: project);
                        } else if (val == 'archive') {
                          _handleArchiveProject(project);
                        } else if (val == 'delete') {
                          _handleDeleteProject(project);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Color(0xFF2E6FF2),
                              ),
                              const SizedBox(width: 8),
                              Text(context.tr('edit_waiting_title')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.archive_outlined,
                                size: 18,
                                color: Color(0xFF8B5CF6),
                              ),
                              const SizedBox(width: 8),
                              Text(context.tr('archive_action_btn')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: AppColors.errorRed,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('delete_group_btn'),
                                style: const TextStyle(
                                  color: AppColors.errorRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  project.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 10),

                // Bottom Meta: Deadline & Linked Tasks Toggle
                Row(
                  children: [
                    if (project.deadline != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? AppColors.errorRed.withValues(alpha: 0.14)
                              : (isDark
                                    ? Colors.white10
                                    : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: isOverdue
                              ? Border.all(
                                  color: AppColors.errorRed.withValues(
                                    alpha: 0.4,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_rounded,
                              size: 13,
                              color: isOverdue
                                  ? AppColors.errorRed
                                  : secondaryTextColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatRelativeDeadline(
                                context,
                                project.deadline!,
                              ),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isOverdue
                                    ? AppColors.errorRed
                                    : secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),

                    // Expand/Collapse Tasks Preview Button
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedProjectIds.remove(project.id);
                          } else {
                            _expandedProjectIds.add(project.id);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 15,
                              color: linkedTasks.isNotEmpty
                                  ? const Color(0xFF10B981)
                                  : secondaryTextColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              context.tr(
                                'linked_tasks_count',
                                args: {'count': linkedTasks.length.toString()},
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: linkedTasks.isNotEmpty
                                    ? primaryTextColor
                                    : secondaryTextColor,
                              ),
                            ),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: secondaryTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsible Linked Tasks View
          if (isExpanded) ...[
            Divider(color: borderColor, height: 1),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('project_tasks_header'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: secondaryTextColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => AddEditTaskSheet.show(
                          context,
                          initialProjectId: project.id,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: Color(0xFF2E6FF2),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('add_task_to_project'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2E6FF2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (linkedTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        context.tr('no_tasks_in_project'),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: secondaryTextColor.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: linkedTasks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final task = linkedTasks[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF0F1B4C)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => ref
                                    .read(tasksControllerProvider)
                                    .toggleTaskDone(task, context),
                                child: Icon(
                                  task.done
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: task.done
                                      ? const Color(0xFF10B981)
                                      : secondaryTextColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: task.done
                                        ? secondaryTextColor
                                        : primaryTextColor,
                                    decoration: task.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E6FF2).withValues(alpha: 0.2),
                    const Color(0xFF00D2FF).withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.folder_special_rounded,
                color: Color(0xFF2E6FF2),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('projects_empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('projects_empty_prompt'),
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
              onPressed: () => AddEditProjectSheet.show(
                context,
                initialAreaId: _selectedFilterAreaId,
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.tr('create_first_project_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E6FF2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
