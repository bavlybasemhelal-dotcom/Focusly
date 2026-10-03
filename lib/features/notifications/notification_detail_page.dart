import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../groups/group_detail_page.dart';
import '../groups/groups_home_page.dart';
import '../habits/habits_screen.dart';
import '../pomodoro/pomodoro_screen.dart';
import '../schedule/schedule_screen.dart';
import '../tasks/tasks_screen.dart';
import 'models/notification_log_model.dart';
import 'providers/notifications_provider.dart';

/// Dedicated Notification Detail Screen.
///
/// Displays the full un-truncated title, body, timestamp, type classification,
/// and read status indicator for a specific notification.
///
/// ARCHITECTURE & INTERACTION NOTE:
/// Tapping a notification in the Notifications list opens this detail screen and
/// marks it as read. The previous automatic direct jump to the related task/event/habit
/// is now an explicit, deliberate action via the bottom action button on this screen
/// when [NotificationLogModel.relatedId] is present.
class NotificationDetailPage extends ConsumerWidget {
  final NotificationLogModel notification;

  const NotificationDetailPage({super.key, required this.notification});

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final dialogBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFE2E8F5),
            width: 1.2,
          ),
        ),
        title: Text(
          context.tr('delete_notification_confirm_title'),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: primaryTextColor,
            fontSize: 20,
          ),
        ),
        content: Text(
          context.tr('delete_notification_confirm_msg'),
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.tr('cancel'),
              style: TextStyle(
                color: secondaryTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref
                  .read(notificationsControllerProvider)
                  .deleteNotification(notification.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              context.tr('delete'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToRelatedItem(BuildContext context) {
    HapticFeedback.lightImpact();
    final relatedId = notification.relatedId;
    if (relatedId == null || relatedId.isEmpty) return;

    // Use Navigator.push (not pushReplacement or tab switching) so the destination
    // sits on top of NotificationDetailPage in the navigation stack.
    // Wrap tab-root destinations in _NotificationDestinationWrapper to ensure a proper
    // AppBar with back button is always available in this navigation flow.
    switch (notification.type) {
      case 'task_reminder':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationDestinationWrapper(
              title: context.tr('tasks'),
              child: const TasksScreen(),
            ),
          ),
        );
        break;
      case 'event_reminder':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationDestinationWrapper(
              title: context.tr('schedule'),
              child: const ScheduleScreen(),
            ),
          ),
        );
        break;
      case 'habit_reminder':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationDestinationWrapper(
              title: context.tr('habits'),
              child: const HabitsScreen(),
            ),
          ),
        );
        break;
      case 'pomodoro':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationDestinationWrapper(
              title: context.tr('pomodoro'),
              child: const PomodoroScreen(),
            ),
          ),
        );
        break;
      case 'group_activity':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => relatedId.isNotEmpty
                ? GroupDetailPage(groupId: relatedId)
                : _NotificationDestinationWrapper(
                    title: context.tr('groups_and_challenges_title'),
                    child: const GroupsHomePage(),
                  ),
          ),
        );
        break;
      case 'system':
      default:
        // Default navigation fallback
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _NotificationDestinationWrapper(
              title: context.tr('tasks'),
              child: const TasksScreen(),
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);

    final typeConfig = _getTypeConfig(notification.type, context);
    final hasRelatedItem =
        notification.relatedId != null &&
        notification.relatedId!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('notification_detail_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppColors.errorRed,
              size: 22,
            ),
            tooltip: context.tr('delete_notification_btn'),
            onPressed: () => _showDeleteConfirmation(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Large Type Hero Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.25)
                                : typeConfig.color.withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Hero Type Icon
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: typeConfig.color.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: typeConfig.color.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    typeConfig.icon,
                                    color: typeConfig.color,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Type Tag
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: typeConfig.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        typeConfig.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: typeConfig.color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // Read Status Badge
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 14,
                                          color: Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.tr(
                                            'notification_status_read',
                                          ),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 18),

                          // Notification Title (Full un-truncated text)
                          Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: primaryTextColor,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Notification Body (Full un-truncated text)
                          Text(
                            notification.body,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : AppColors.lightTextPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Metadata Information Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetaRow(
                            icon: Icons.access_time_rounded,
                            label: context.tr('notification_timestamp_label'),
                            value: _formatFullDateTime(
                              notification.createdAt,
                              context,
                            ),
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            brandPrimary: brandPrimary,
                          ),
                          if (notification.isScheduled &&
                              notification.scheduledFor != null) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 14),
                            _buildMetaRow(
                              icon: Icons.schedule_rounded,
                              label: context.tr(
                                'notification_scheduled_time_label',
                              ),
                              value: _formatFullDateTime(
                                notification.scheduledFor!,
                                context,
                              ),
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                              brandPrimary: const Color(0xFFF59E0B),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. "Go to related item" Action Button (if relatedId is present)
            if (hasRelatedItem)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToRelatedItem(context),
                    icon: Icon(typeConfig.actionIcon, size: 20),
                    label: Text(
                      typeConfig.actionLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeConfig.color,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(icon, color: brandPrimary, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Formats exact date and time (e.g. "27 Aug 2026, 10:30 AM")
  String _formatFullDateTime(DateTime dt, BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const monthsAr = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    final monthName = isArabic
        ? monthsAr[dt.month - 1]
        : monthsEn[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12
        ? (isArabic ? 'م' : 'PM')
        : (isArabic ? 'ص' : 'AM');
    return '${dt.day} $monthName ${dt.year}, $hour:$minute $period';
  }

  _TypeDetailConfig _getTypeConfig(String type, BuildContext context) {
    switch (type) {
      case 'task_reminder':
        return _TypeDetailConfig(
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF3B82F6),
          label: context.tr('notification_type_task'),
          actionIcon: Icons.task_alt_rounded,
          actionLabel: context.tr('notification_view_task'),
        );
      case 'event_reminder':
        return _TypeDetailConfig(
          icon: Icons.event_available_rounded,
          color: const Color(0xFF10B981),
          label: context.tr('notification_type_event'),
          actionIcon: Icons.event_note_rounded,
          actionLabel: context.tr('notification_view_event'),
        );
      case 'habit_reminder':
        return _TypeDetailConfig(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFF59E0B),
          label: context.tr('notification_type_habit'),
          actionIcon: Icons.local_fire_department_rounded,
          actionLabel: context.tr('notification_view_habit'),
        );
      case 'pomodoro':
        return _TypeDetailConfig(
          icon: Icons.timer_rounded,
          color: const Color(0xFFEF4444),
          label: context.tr('notification_type_pomodoro'),
          actionIcon: Icons.timer_rounded,
          actionLabel: context.tr('notification_view_pomodoro'),
        );
      case 'group_activity':
        return _TypeDetailConfig(
          icon: Icons.groups_rounded,
          color: const Color(0xFF06B6D4),
          label: context.tr('notification_type_group'),
          actionIcon: Icons.groups_rounded,
          actionLabel: context.tr('notification_view_group'),
        );
      case 'system':
      default:
        return _TypeDetailConfig(
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF8B5CF6),
          label: context.tr('notification_type_system'),
          actionIcon: Icons.arrow_forward_rounded,
          actionLabel: context.tr('notification_view_related'),
        );
    }
  }
}

class _TypeDetailConfig {
  final IconData icon;
  final Color color;
  final String label;
  final IconData actionIcon;
  final String actionLabel;

  const _TypeDetailConfig({
    required this.icon,
    required this.color,
    required this.label,
    required this.actionIcon,
    required this.actionLabel,
  });
}

/// Route-specific wrapper that provides an explicit AppBar with a back button
/// when pushing tab-root screens (like TasksScreen, ScheduleScreen, HabitsScreen, PomodoroScreen)
/// from the Notification Detail screen.
///
/// ARCHITECTURE & REUSE NOTE:
/// TasksScreen, ScheduleScreen, and HabitsScreen are normally rendered as tab roots
/// in the main navigation shell without their own top back button (since tabs don't have
/// back buttons). When opened from NotificationDetailPage via "View Task/Event/Habit",
/// we wrap them in this lightweight Scaffold+AppBar with a back button so users can
/// naturally navigate back to the Notification Detail screen (and then back to the Notifications list).
class _NotificationDestinationWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const _NotificationDestinationWrapper({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: child,
    );
  }
}
