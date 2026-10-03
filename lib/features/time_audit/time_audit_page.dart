import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../tasks/models/category_model.dart';
import '../tasks/providers/tasks_provider.dart';
import 'models/time_audit_model.dart';
import 'providers/time_audit_provider.dart';
import 'widgets/quick_log_bar.dart';
import 'widgets/time_distribution_chart.dart';

/// Time Audit screen featuring Period Filtering, Quick Log Bar,
/// Combined Time Distribution Chart, and Manual Entries Management.
class TimeAuditPage extends ConsumerWidget {
  const TimeAuditPage({super.key});

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F1B4C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('clear_all_logs_title'),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          context.tr('clear_all_logs_msg'),
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(context.tr('clear_all_btn')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await ref.read(timeAuditServiceProvider).clearAllLogs(uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('all_logs_cleared_toast')),
              backgroundColor: AppColors.errorRed,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    TimeAuditLogModel log,
  ) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    HapticFeedback.selectionClick();
    await ref.read(timeAuditServiceProvider).deleteLog(uid: uid, logId: log.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('log_deleted_toast')),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final currentPeriod = ref.watch(timeAuditPeriodFilterProvider);
    final manualLogs = ref.watch(filteredManualLogsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final allCategories =
        categoriesAsync.value ?? TaskCategory.defaultCategories;
    final categoriesMap = {for (var c in allCategories) c.id: c};

    final periods = [
      {'key': 'week', 'label': context.tr('period_this_week')},
      {'key': 'month', 'label': context.tr('period_this_month')},
      {'key': 'all', 'label': context.tr('period_all_time')},
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('time_audit_title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
          ),
        ),
        actions: [
          if (manualLogs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep_rounded, color: AppColors.errorRed),
              tooltip: context.tr('clear_all_btn'),
              onPressed: () => _confirmClearAll(context, ref),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Period Selector Chips Row
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF08123A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: periods.map((p) {
                  final key = p['key']!;
                  final label = p['label']!;
                  final isSelected = currentPeriod == key;

                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(timeAuditPeriodFilterProvider.notifier)
                            .setPeriod(key);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2E6FF2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2E6FF2,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Quick Log Bar (Inline Entry Form)
            const QuickLogBar(),
            const SizedBox(height: 20),

            // 3. Time Distribution Chart
            const TimeDistributionChart(),
            const SizedBox(height: 24),

            // 4. Manual Entries Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.tr('manual_entries_header'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  '${manualLogs.length} ${context.tr('entries_unit')}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 5. Manual Entries List
            if (manualLogs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text('📝', style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('no_manual_entries_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('no_manual_entries_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              )
            else
              ...manualLogs.map((log) {
                final category =
                    categoriesMap[log.category] ??
                    TaskCategory(
                      id: log.category,
                      nameKey: log.category,
                      colorValue: 0xFF2E6FF2,
                    );

                final catName = category.isDefault
                    ? context.tr(category.nameKey)
                    : category.nameKey;

                final formattedDate = DateFormat.MMMd().format(log.date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      // Category color indicator bar
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: category.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Description & Date/Category Chip
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              log.description.isNotEmpty
                                  ? log.description
                                  : context.tr('manual_activity_default'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Category Tag Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: category.color.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    catName,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: category.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Date
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Hours Tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E6FF2).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${log.hours} ${context.tr('hours_unit')}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E6FF2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Delete Button
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.errorRed,
                        ),
                        onPressed: () => _deleteEntry(context, ref, log),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
