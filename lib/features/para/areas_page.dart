import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/para_area_model.dart';
import 'projects_page.dart';
import 'providers/para_provider.dart';
import 'widgets/add_edit_area_sheet.dart';

/// Screen displaying all PARA Areas of Responsibility with live active project counts.
class AreasPage extends ConsumerWidget {
  const AreasPage({super.key});

  Future<void> _handleDeleteArea(
    BuildContext context,
    WidgetRef ref,
    ParaAreaModel area,
    int activeProjectsCount,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);

    // 1. Guard against deleting an Area with active projects
    if (activeProjectsCount > 0) {
      HapticFeedback.heavyImpact();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('cannot_delete_area_title'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            context.tr(
              'area_has_active_projects_msg',
              args: {'count': activeProjectsCount.toString()},
            ),
            style: TextStyle(
              fontSize: 14,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                context.tr('close'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Confirmation dialog for empty area
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          context.tr('delete_area_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        content: Text(
          context.tr('delete_area_confirm_msg', args: {'title': area.title}),
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
      final success = await ref.read(paraServiceProvider).deleteArea(area.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? context.tr('area_deleted_toast')
                  : context.tr('cannot_delete_area_title'),
            ),
            backgroundColor: success
                ? const Color(0xFF10B981)
                : AppColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final scaffoldBg = isDark
        ? const Color(0xFF070D28)
        : const Color(0xFFF8FAFC);

    final areasAsync = ref.watch(paraAreasStreamProvider);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          context.tr('para_areas_title'),
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
                onPressed: () => AddEditAreaSheet.show(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(context.tr('add_area_btn')),
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
      body: areasAsync.when(
        data: (areas) {
          if (areas.isEmpty) {
            return _buildEmptyState(
              context,
              isDark,
              primaryTextColor,
              secondaryTextColor,
            );
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
            children: [
              // Intro Card / Header
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F1B4C).withValues(alpha: 0.6)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E6FF2), Color(0xFF00D2FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.domain_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('areas_subtitle'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Grid of Areas
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemCount: areas.length,
                itemBuilder: (context, index) {
                  final area = areas[index];
                  final activeProjectsCount = ref.watch(
                    areaActiveProjectsCountProvider(area.id),
                  );

                  return _buildAreaCard(
                    context,
                    ref,
                    area,
                    activeProjectsCount,
                    isDark,
                    primaryTextColor,
                    secondaryTextColor,
                  );
                },
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text(
            context.tr('areas_load_error'),
            style: const TextStyle(color: AppColors.errorRed),
          ),
        ),
      ),
    );
  }

  Widget _buildAreaCard(
    BuildContext context,
    WidgetRef ref,
    ParaAreaModel area,
    int activeProjectsCount,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFE2E8F5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProjectsPage(initialFilterAreaId: area.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      area.emoji,
                      style: const TextStyle(fontSize: 22),
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
                        AddEditAreaSheet.show(context, area: area);
                      } else if (val == 'delete') {
                        _handleDeleteArea(
                          context,
                          ref,
                          area,
                          activeProjectsCount,
                        );
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: activeProjectsCount > 0
                          ? const Color(0xFF2E6FF2).withValues(alpha: 0.12)
                          : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr(
                        'active_projects_count',
                        args: {'count': activeProjectsCount.toString()},
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: activeProjectsCount > 0
                            ? const Color(0xFF2E6FF2)
                            : secondaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
              child: const Center(
                child: Text('🎯', style: TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('areas_empty_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('areas_empty_prompt'),
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
              onPressed: () => AddEditAreaSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.tr('create_first_area_btn')),
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
