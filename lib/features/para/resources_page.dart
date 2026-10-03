import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/para_resource_model.dart';
import 'providers/para_provider.dart';
import 'widgets/add_edit_resource_sheet.dart';

/// Screen displaying active PARA Knowledge Resources with tag filters and note previews.
class ResourcesPage extends ConsumerStatefulWidget {
  const ResourcesPage({super.key});

  @override
  ConsumerState<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends ConsumerState<ResourcesPage> {
  String? _selectedTag;

  Future<void> _handleArchiveResource(ParaResourceModel resource) async {
    HapticFeedback.lightImpact();
    await ref
        .read(paraServiceProvider)
        .setResourceArchived(resource.id, archived: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('resource_archived_toast')),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleDeleteResource(ParaResourceModel resource) async {
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
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        content: Text(
          context.tr(
            'delete_resource_confirm_msg',
            args: {'title': resource.title},
          ),
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
    final scaffoldBg = isDark
        ? const Color(0xFF070D28)
        : const Color(0xFFF8FAFC);

    final resourcesAsync = ref.watch(paraResourcesStreamProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('para_resources_title'),
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
                onPressed: () => AddEditResourceSheet.show(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('add_resource_btn')),
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
      body: resourcesAsync.when(
        data: (resources) {
          // Extract unique tags
          final Set<String> allTags = {};
          for (final r in resources) {
            allTags.addAll(r.tags);
          }

          final filteredResources = _selectedTag == null
              ? resources
              : resources.where((r) => r.tags.contains(_selectedTag)).toList();

          return Column(
            children: [
              // Tags Filter Bar
              if (allTags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTagFilterChip(
                          label: context.tr('all_tags_filter'),
                          isSelected: _selectedTag == null,
                          onTap: () => setState(() => _selectedTag = null),
                          isDark: isDark,
                          brandPrimary: brandPrimary,
                        ),
                        const SizedBox(width: 8),
                        ...allTags.map((tag) {
                          final isSelected = _selectedTag == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildTagFilterChip(
                              label: '#$tag',
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedTag = isSelected ? null : tag;
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

              // Main List
              Expanded(
                child: filteredResources.isEmpty
                    ? _buildEmptyState(
                        context,
                        isDark,
                        primaryTextColor,
                        secondaryTextColor,
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 90),
                        itemCount: filteredResources.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final resource = filteredResources[index];
                          return _buildResourceCard(
                            context,
                            resource,
                            isDark,
                            primaryTextColor,
                            secondaryTextColor,
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
            context.tr('resources_load_error'),
            style: const TextStyle(color: AppColors.errorRed),
          ),
        ),
      ),
    );
  }

  Widget _buildTagFilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context,
    ParaResourceModel resource,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.source_rounded,
                  color: Color(0xFF06B6D4),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    if (resource.notes != null &&
                        resource.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        resource.notes!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: secondaryTextColor,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: secondaryTextColor,
                  size: 20,
                ),
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (val) {
                  if (val == 'edit') {
                    AddEditResourceSheet.show(context, resource: resource);
                  } else if (val == 'archive') {
                    _handleArchiveResource(resource);
                  } else if (val == 'delete') {
                    _handleDeleteResource(resource);
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
                          style: const TextStyle(color: AppColors.errorRed),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Tag chips
          if (resource.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: resource.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: secondaryTextColor,
                    ),
                  ),
                );
              }).toList(),
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
                    const Color(0xFF06B6D4).withValues(alpha: 0.2),
                    const Color(0xFF00D2FF).withValues(alpha: 0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.source_rounded,
                color: Color(0xFF06B6D4),
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('resources_empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('resources_empty_prompt'),
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
              onPressed: () => AddEditResourceSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.tr('create_first_resource_btn')),
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
