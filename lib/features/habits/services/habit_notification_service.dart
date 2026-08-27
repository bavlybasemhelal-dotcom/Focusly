import '../../../core/notifications/platform_senders/platform_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../../notifications/services/notification_logger.dart';
import '../models/habit_model.dart';

/// Service responsible for managing local notifications for daily Habits in Focusly.
///
/// Schedules daily-repeating alerts at the habit's configured reminder time
/// using [PlatformNotificationSender] across Mobile, Web, and Desktop.
class HabitNotificationService {
  static final HabitNotificationService _instance =
      HabitNotificationService._internal();
  factory HabitNotificationService() => _instance;
  HabitNotificationService._internal();

  PlatformNotificationSender get _platformSender =>
      NotificationInitService.platformSender;

  /// Generates a stable 32-bit positive integer ID for the habit notification
  static int getNotificationId(String habitId) {
    return habitId.hashCode.abs() & 0x7FFFFFFF;
  }

  /// Schedules or reschedules a daily recurring notification for a habit
  Future<void> scheduleHabitReminder({
    required HabitModel habit,
    required String notificationTitle,
  }) async {
    if (habit.time == null) {
      await cancelHabitReminder(habit.id);
      return;
    }

    try {
      await NotificationInitService.initializeAppNotifications();
      await NotificationInitService.requestPermissions();

      final int notificationId = getNotificationId(habit.id);

      // Cancel previous notification if any
      await _platformSender.cancelNotification(notificationId);

      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        habit.time!.hour,
        habit.time!.minute,
      );

      // If scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _platformSender.scheduleNotification(
        id: notificationId,
        title: notificationTitle,
        body: habit.title,
        scheduledDate: scheduledDate,
        channelId: 'focusly_habits_channel',
        channelName: 'Habit Reminders',
        payload: habit.id,
      );

      await NotificationLogger.logNotification(
        title: notificationTitle,
        body: habit.title,
        type: 'habit_reminder',
        relatedId: habit.id,
        isScheduled: true,
        scheduledFor: scheduledDate,
      );
    } catch (_) {
      // Graceful fallback if device permissions are not yet granted
    }
  }

  /// Cancels any scheduled notification for a given habit ID
  Future<void> cancelHabitReminder(String habitId) async {
    try {
      final int notificationId = getNotificationId(habitId);
      await _platformSender.cancelNotification(notificationId);
    } catch (_) {}
  }
}
