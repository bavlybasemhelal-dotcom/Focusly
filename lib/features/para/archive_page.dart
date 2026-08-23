import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/para_project_model.dart';
import 'models/para_resource_model.dart';
import 'providers/para_provider.dart';

/// Screen displaying all archived Projects and Resources with restore and permanent delete actions.
class ArchivePage extends ConsumerStatefulWidget {
  const ArchivePage({super.key});

  @override
  ConsumerState<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends ConsumerState<ArchivePage> {
  int _selectedTab = 0; // 0 = Projects, 1 = Resources

  Future<void> _handleRestoreProject(ParaProjectModel project) async {
    HapticFeedback.mediumImpact();
    await ref.read(paraServiceProvider).setProjectArchived(project.id, archived: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('project_restored_toast')),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handlePermanentDeleteProject(ParaProjectModel project) async {
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
          style: TextStyle(fontWeight: FontWeight.w900, color: primaryTextColor),
        ),
        content: Text(
          context.tr('delete_project_confirm_msg', args: {'title': project.title}),
          style: TextStyle(color: secondaryTextColor),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _handleRestoreResource(ParaResourceModel resource) async {
    HapticFeedback.mediumImpact();
    await ref.read(paraServiceProvider).setResourceArchived(resource.id, archived: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('resource_restored_toast')),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handlePermanentDeleteResource(ParaResourceModel resource) async {
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
          context.tr('delete_resource_confirm_title'),
          style: TextStyle(fontWeight: FontWeight.w900, color: primaryTextColor),
        ),
        content: Text(
          context.tr('delete_resource_confirm_msg', args: {'title': resource.title}),
          style: TextStyle(color: secondaryTextColor),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('delete_group_btn')),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(paraServiceProvider).deleteResource(resource.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('resource_deleted_toast')),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final scaffoldBg = isDark ? const Color(0xFF070D28) : const Color(0xFFF8FAFC);

    final archivedProjectsAsync = ref.watch(archivedProjectsStreamProvider);
    final archivedResourcesAsync = ref.watch(archivedResourcesStreamProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('para_archive_title'),
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
      ),
      body: Column(
        children: [
          // Segmented Tab Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F1B4C) : const Color(0xFFE2E8F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      label: context.tr('archived_projects_tab'),
                      icon: Icons.folder_special_rounded,
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                      brandPrimary: brandPrimary,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      label: context.tr('archived_resources_tab'),
                      icon: Icons.source_rounded,
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                      brandPrimary: brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Tab View Content
          Expanded(
            child: _selectedTab == 0
                ? archivedProjectsAsync.when(
                    data: (projects) => projects.isEmpty
                        ? _buildEmptyArchive(
                            context,
                            context.tr('no_archived_projects_title'),
                            context.tr('no_archived_projects_prompt'),
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                            itemCount: projects.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final project = projects[index];
                              return _buildArchivedCard(
                                context: context,
                                title: project.title,
                                icon: Icons.folder_special_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                onRestore: () => _handleRestoreProject(project),
                                onDelete: () => _handlePermanentDeleteProject(project),
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              );
                            },
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text(
                        context.tr('projects_load_error'),
                        style: const TextStyle(color: AppColors.errorRed),
                      ),
                    ),
                  )
                : archivedResourcesAsync.when(
                    data: (resources) => resources.isEmpty
                        ? _buildEmptyArchive(
                            context,
                            context.tr('no_archived_resources_title'),
                            context.tr('no_archived_resources_prompt'),
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                            itemCount: resources.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final resource = resources[index];
                              return _buildArchivedCard(
                                context: context,
                                title: resource.title,
                                subtitle: resource.notes,
                                icon: Icons.source_rounded,
                                iconColor: const Color(0xFF06B6D4),
                                onRestore: () => _handleRestoreResource(resource),
                                onDelete: () => _handlePermanentDeleteResource(resource),
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              );
                            },
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text(
                        context.tr('resources_load_error'),
                        style: const TextStyle(color: AppColors.errorRed),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color brandPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedCard({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onRestore,
    required VoidCallback onDelete,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.unarchive_rounded, color: Color(0xFF10B981), size: 22),
            onPressed: onRestore,
            tooltip: context.tr('restore_action_btn'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.errorRed, size: 22),
            onPressed: onDelete,
            tooltip: context.tr('delete_group_btn'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyArchive(
    BuildContext context,
    String title,
    String subtitle,
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                color: secondaryTextColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
