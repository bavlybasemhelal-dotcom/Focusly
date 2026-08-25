import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import 'models/notification_log_model.dart';
import 'providers/notifications_provider.dart';

/// Notifications History & Activity Feed Screen.
///
/// Displays reverse-chronological delivered notifications (Tasks, Schedule Events,
/// Habits, Pomodoro, Groups, and System alerts) with unread status, mark-all-read,
/// and tap-to-read actions.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final brandPrimary = AppColors.brandPrimary(context);
    final cardBg = isDark ? const Color(0xFF0F1B4C) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE2E8F5);
    final bgColor = isDark ? AppColors.darkBg : AppColors.lightBg;

    final logsAsync = ref.watch(notificationLogsStreamProvider);
    final logs = logsAsync.value ?? <NotificationLogModel>[];
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.tr('notifications_title'),
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brandPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(notificationsControllerProvider).markAllAsRead();
              },
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(
                context.tr('mark_all_read_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: brandPrimary,
              ),
            ),
        ],
      ),
      body: logsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _buildEmptyState(
              context: context,
              isDark: isDark,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              brandPrimary: brandPrimary,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = items[index];
              return _buildNotificationCard(
                context: context,
                ref: ref,
                log: log,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                brandPrimary: brandPrimary,
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => _buildEmptyState(
          context: context,
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          brandPrimary: brandPrimary,
        ),
      ),
    );
  }

  /// Builds an individual notification tile
  Widget _buildNotificationCard({
    required BuildContext context,
    required WidgetRef ref,
    required NotificationLogModel log,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    final typeConfig = _getTypeConfig(log.type);

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(notificationsControllerProvider).deleteNotification(log.id);
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (!log.read) {
              ref.read(notificationsControllerProvider).markAsRead(log.id);
            }
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: log.read
                  ? cardBg
                  : (isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                      : const Color(0xFFF0F7FF)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: log.read
                    ? borderColor
                    : (isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD)),
                width: log.read ? 1.0 : 1.4,
              ),
              boxShadow: isDark || log.read
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF2E6FF2).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon Container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: typeConfig.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      typeConfig.icon,
                      color: typeConfig.color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              log.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: log.read
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                color: primaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(log.createdAt, context),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        log.body,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: log.read ? FontWeight.w400 : FontWeight.w600,
                          color: log.read
                              ? secondaryTextColor
                              : primaryTextColor.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Unread Indicator Dot
                if (!log.read)
                  Container(
                    margin: const EdgeInsets.only(left: 8, top: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: brandPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds empty state when zero notifications exist
  Widget _buildEmptyState({
    required BuildContext context,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color brandPrimary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brandPrimary.withValues(alpha: 0.12),
              ),
              child: Center(
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: brandPrimary,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('no_notifications_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('no_notifications_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats relative time (e.g. "Just now", "5m ago", "2h ago", "Yesterday")
  String _formatRelativeTime(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return context.tr('time_just_now');
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays == 1) {
      return context.tr('time_yesterday');
    } else {
      return '${difference.inDays}d';
    }
  }

  _TypeVisualConfig _getTypeConfig(String type) {
    switch (type) {
      case 'task_reminder':
        return _TypeVisualConfig(
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF3B82F6),
        );
      case 'event_reminder':
        return _TypeVisualConfig(
          icon: Icons.event_available_rounded,
          color: const Color(0xFF10B981),
        );
      case 'habit_reminder':
        return _TypeVisualConfig(
          icon: Icons.local_fire_department_rounded,
          color: const Color(0xFFF59E0B),
        );
      case 'pomodoro':
        return _TypeVisualConfig(
          icon: Icons.timer_rounded,
          color: const Color(0xFFEF4444),
        );
      case 'group_activity':
        return _TypeVisualConfig(
          icon: Icons.groups_rounded,
          color: const Color(0xFF06B6D4),
        );
      case 'system':
      default:
        return _TypeVisualConfig(
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF8B5CF6),
        );
    }
  }
}

class _TypeVisualConfig {
  final IconData icon;
  final Color color;

  const _TypeVisualConfig({
    required this.icon,
    required this.color,
  });
}
