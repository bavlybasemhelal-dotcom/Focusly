import 'package:flutter/foundation.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/platform_senders/platform_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../../notifications/services/notification_logger.dart';
import '../models/task_model.dart';

/// Service responsible for scheduling and cancelling local task reminder notifications.
///
/// Uses [PlatformNotificationSender] to reliably deliver notifications to the OS system tray
/// across Mobile (Android/iOS), Web (Browser Notification API), and Desktop (Windows/macOS/Linux).
class TaskNotificationService {
  static final TaskNotificationService _instance =
      TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  PlatformNotificationSender get _platformSender =>
      NotificationInitService.platformSender;

  /// Generates a stable unique integer notification ID from task ID and slot (0, 1, 2)
  int _generateNotificationId(String taskId, int slot) {
    return (taskId.hashCode ^ (slot * 31)).abs() & 0x7FFFFFFF;
  }

  /// Schedules all relevant notifications for a task:
  /// 1. Specific Task Time Notification (at exact scheduled date + time)
  /// 2. 24 Hours Before Deadline Notification
  /// 3. 1 Hour Before Deadline Notification
  Future<void> scheduleTaskNotifications(
    TaskModel task,
    AppLocalizations localizations,
  ) async {
    // Ensure core notifications and permissions are ready
    await NotificationInitService.initializeAppNotifications();
    await NotificationInitService.requestPermissions();

    // Always clear prior scheduled slots first to prevent duplicate or stale alerts
    await cancelTaskNotifications(task.id);

    // If task is completed, do not schedule any upcoming alerts
    if (task.done) return;

    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // 1. SPECIFIC TASK TIME NOTIFICATION
    // -------------------------------------------------------------------------
    if (task.time != null) {
      final scheduledDateTime = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.time!.hour,
        task.time!.minute,
      );

      if (scheduledDateTime.isAfter(now)) {
        try {
          final id = _generateNotificationId(task.id, 0);
          final title = localizations.tr('notification_task_time_title');
          final body =
              '${task.title} • ${task.time!.hour.toString().padLeft(2, '0')}:${task.time!.minute.toString().padLeft(2, '0')}';

          await _platformSender.scheduleNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: scheduledDateTime,
            channelId: 'task_reminders',
            channelName: 'Task Reminders',
            payload: task.id,
          );

          // Record in notification history log with scheduled metadata
          await NotificationLogger.logNotification(
            title: title,
            body: body,
            type: 'task_reminder',
            relatedId: task.id,
            isScheduled: true,
            scheduledFor: scheduledDateTime,
          );
        } catch (e) {
          debugPrint('Error scheduling task time notification: $e');
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. DEADLINE NOTIFICATIONS (24h before & 1h before)
    // -------------------------------------------------------------------------
    if (task.deadline != null) {
      // 2a. 24 Hours Before Deadline
      final deadline24h = task.deadline!.subtract(const Duration(hours: 24));
      if (deadline24h.isAfter(now)) {
        try {
          final id24 = _generateNotificationId(task.id, 1);
          final title24 = localizations.tr('notification_deadline_24h_title');
          final body24 = task.title;

          await _platformSender.scheduleNotification(
            id: id24,
            title: title24,
            body: body24,
            scheduledDate: deadline24h,
            channelId: 'task_deadlines',
            channelName: 'Task Deadlines',
            payload: task.id,
          );

          await NotificationLogger.logNotification(
            title: title24,
            body: body24,
            type: 'task_reminder',
            relatedId: task.id,
            isScheduled: true,
            scheduledFor: deadline24h,
          );
        } catch (e) {
          debugPrint('Error scheduling 24h deadline notification: $e');
        }
      }

      // 2b. 1 Hour Before Deadline
      final deadline1h = task.deadline!.subtract(const Duration(hours: 1));
      if (deadline1h.isAfter(now)) {
        try {
          final id1 = _generateNotificationId(task.id, 2);
          final title1 = localizations.tr('notification_deadline_1h_title');
          final body1 = task.title;

          await _platformSender.scheduleNotification(
            id: id1,
            title: title1,
            body: body1,
            scheduledDate: deadline1h,
            channelId: 'task_deadlines',
            channelName: 'Task Deadlines',
            payload: task.id,
          );

          await NotificationLogger.logNotification(
            title: title1,
            body: body1,
            type: 'task_reminder',
            relatedId: task.id,
            isScheduled: true,
            scheduledFor: deadline1h,
          );
        } catch (e) {
          debugPrint('Error scheduling 1h deadline notification: $e');
        }
      }
    }
  }

  /// Cancels all scheduled notification slots for a given task ID
  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await _platformSender.cancelNotification(_generateNotificationId(taskId, 0));
      await _platformSender.cancelNotification(_generateNotificationId(taskId, 1));
      await _platformSender.cancelNotification(_generateNotificationId(taskId, 2));
    } catch (e) {
      debugPrint('Error cancelling task notifications: $e');
    }
  }
}
